{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  secretFilter =
    lib.throwIf (config.secrets.env.export.all == true && config.secrets.env.export.keys != [ ])
      "sops wrapper: secrets.env.export.all and secrets.env.export.keys are mutually exclusive"
      (
        if config.secrets.env.export.keys != [ ] then
          ''grep -E "^(${lib.concatStringsSep "|" config.secrets.env.export.keys})="''
        else
          ''grep -v "^sops_"''
      );

  hasPolicy = config.settings != { } || (config.configFile.content or "") != "";

  exportSecrets = config.secrets.env.export.all != false || config.secrets.env.export.keys != [ ];
in
{
  imports = [ wlib.modules.default ];
  options = {
    secrets.file = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Sops-encrypted dotenv file.

        When set, the wrapped program is launched with these attrs decrypted
        into its process env (runtime secrets, nothing plaintext is stored),
        instead of wrapping the sops CLI itself. Values are sourced unquoted,
        so keep secrets to plain key=value attrs.
      '';
    };

    secrets.env.export.all = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Export every attr of secrets.file into the wrapped process env.
        Defaults to yes when secrets.env.export.keys is empty. Setting true is
        mutually exclusive with secrets.env.export.keys.
      '';
    };

    secrets.env.export.keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "OPENAI_API_KEY"
        "ANTHROPIC_API_KEY"
      ];
      description = ''
        Export only these attrs of secrets.file into the wrapped process env.
        Mutually exclusive with secrets.env.export.all = true.
      '';
    };

    age.yubikey = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Add age-plugin-yubikey to the wrapper runtime so sops can decrypt
        yubikey recipients (age itself is built into sops).
      '';
    };

    age.keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/alice/.config/sops/age/keys.txt";
      description = ''
        Age identity file, exported as SOPS_AGE_KEY_FILE.

        A string so nothing is copied into the world-readable nix store
        unless you ask for it: pass an absolute system path for real
        private identities, or toString of a checkout path for public
        material only (yubikey stubs). When unset, sops uses its native
        discovery (~/.config/sops/age/keys.txt).
      '';
    };

    configFile = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default = { };
      example.path = "/home/alice/.sops.yaml";
      description = ''
        Path or inline definition for the SOPS YAML config file.

        By default, this points to the generated config built from settings.
        If content is set, it is used as literal YAML and settings is ignored.
      '';
    };

    settings = lib.mkOption {
      type = wlib.types.structuredValueWith {
        nullable = false;
        typeName = "YAML";
      };
      default = { };
      example.creation_rules = [
        {
          path_regex = "secrets.yaml$";
          age = "age1...";
        }
      ];
      description = ''
        SOPS YAML configuration as a Nix value.

        This is serialized to a config file delivered via SOPS_CONFIG,
        without schema validation.
        Use configFile.content instead when YAML-specific features like anchors are needed.

        Only needed to create or re-encrypt files: editing an existing
        secrets file re-encrypts to the recipients embedded in the file.

        See <https://getsops.io/docs/>.
      '';
    };
  };
  config = {
    binName = lib.mkDefault "sops";
    package = lib.mkDefault pkgs.sops;

    # sops walks up from the target file for .sops.yaml on its own; only
    # override that discovery when the user actually declared policy here
    envDefault.SOPS_CONFIG = lib.mkIf hasPolicy config.configFile.path;
    envDefault.SOPS_AGE_KEY_FILE = lib.mkIf (config.age.keyFile != null) config.age.keyFile;

    runtimePkgs =
      lib.optional (config.secrets.file != null && exportSecrets) pkgs.sops
      ++ lib.optional config.age.yubikey pkgs.age-plugin-yubikey;

    runShell = lib.mkIf (config.secrets.file != null && exportSecrets) [
      # set -a: sourced assignments must be exported or exec drops them
      "set -a && source <(sops -d --output-type dotenv ${config.secrets.file} | ${secretFilter}) && set +a"
    ];

    # expose the sops cli on the package output for maintaining the secrets
    # file (sops edit/-e). Deliberately raw: native sops behavior, native
    # discovery; decryption backends come from runtimePkgs/the output bins
    constructFiles.sopsBin = lib.mkIf (config.secrets.file != null && exportSecrets) {
      relPath = "bin/sops";
      builder = ''ln -s ${pkgs.sops}/bin/sops "$2"'';
    };

    # and the backend plugin alongside it, so the user's own shell can drive
    # the same decryption without extra PATH setup
    constructFiles.agePluginBin = lib.mkIf config.age.yubikey {
      relPath = "bin/age-plugin-yubikey";
      builder = ''ln -s ${pkgs.age-plugin-yubikey}/bin/age-plugin-yubikey "$2"'';
    };

    constructFiles.generatedConfig = {
      content =
        if (config.configFile.content or "") != "" then
          config.configFile.content
        else
          builtins.toJSON config.settings;
      relPath = "${config.binName}-config.yaml";
      builder = lib.mkIf (
        (config.configFile.content or "") == ""
      ) ''${pkgs.remarshal}/bin/json2yaml "$1" "$2"'';
    };

    meta.description = ''
      Nix wrapper module for SOPS (Secrets OPerationS).
      See <https://getsops.io/docs/>.

      #### Example 1 (Simple):
      Wrap the sops CLI with nix-owned configuration.
      ```nix
        wrappers.sops.wrap {
          inherit pkgs;
          settings.creation_rules = [
            { path_regex = ".*"; age = "age1yubikey1..."; }
          ];
          age.yubikey = true; # optional yubikey inclusions
        }
      ```

      #### Example 2 (Advanced):
      Sops-wrap another wrapper module or program, injecting secrets at launch.

      Decryption is best-effort: on failure, wrapped program still launches.

      ```nix
        wrappers.sops.wrap {
          inherit pkgs;
          binName = "opencode";
          configFile.path = ./.sops.yaml;       # external config file support
          secrets.file = ./secrets.env;         # sops-encrypted dotenv
          secrets.env.exportAll = true;         # or secrets.env.export = [ "KEY" ];
          package = wrappers.opencode.wrap {    # any wrapper, any program
            inherit pkgs;
          };
        }
      ```
    '';
    meta.maintainers = [ wlib.maintainers.smissingham ];
  };
}
