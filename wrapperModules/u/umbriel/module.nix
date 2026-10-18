{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  configPath = config.constructFiles.generatedConfig.path;
  tomlAttrs = lib.types.attrsOf (
    wlib.types.structuredValueWith {
      nullable = false;
      typeName = "TOML";
    }
  );
in
{
  imports = [
    wlib.modules.default
    wlib.modules.systemd
  ];

  config.meta.description = ''
    Wrapper module for [Umbriel](https://docs.noctalia.dev/umbriel/)
  '';

  options = {
    settings = lib.mkOption {
      type = tomlAttrs;
      default = { };
      example = lib.literalExpression ''
        {
          general.autostart = [ "noctalia" ];
          layout.gap = 5;
          input.keyboard.layout = "us";
          keybinds."Mod+Q" = "window-close";
        }'';
      description = ''
        Umbriel configuration settings.
        See <https://docs.noctalia.dev/umbriel/configuration/>
      '';
    };
    includeOptional = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Optional includes for Umbriel
        Useful if you simply want to include a .toml file, instead of writing the configuration in nix
        See <https://docs.noctalia.dev/umbriel/configuration/?section=include#include>
      '';
      example = ''
        [
          "~/.config/umbriel/noctalia.toml",
        ]
      '';
    };
    "config.toml" = lib.mkOption {
      type = wlib.types.file { };
      default = { };
      description = ''
        Overwrite the contents of Umbriels `config.toml`
        Can also be used with builtins.readFile to write the toml config outside of nix
      '';
    };
    enableConfigHotReload = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enables hot reload for Umbriels config when rebuilding
      '';
    };
    enableConfigValidation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When `true`, the build runs `umbriel config validate -c <config>` and fails if it reports anything.

        Disabled by default since validation exits non-zero on warnings as well as errors,
        and the home-manager module also drops it.
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.umbriel;
    filesToPatch = [
      "bin/start-umbriel"
      "lib/systemd/user/umbriel.service"
      "share/applications/*.desktop"
      "share/systemd/user/umbriel.service"
      "share/wayland-sessions/*.desktop"
    ];
    # -c has to be the first argument and umbriel ignores everything after it, therefor we do it this way
    runShell = [
      {
        name = "UMBRIEL_CONFIG_FLAG";
        data = ''
          if [ "$#" -eq 0 ] || [ "$1" = "-s" ]; then
            set -- -c ${lib.escapeShellArg configPath} "$@"
          fi
        '';
      }
    ];
    buildCommand.validateConfig = lib.mkIf config.enableConfigValidation {
      date = ''
        ${lib.getExe config.package} config validate -c ${configPath}
      '';
      after = [
        "runStdenvPhases"
        "makeWrapper"
      ];
    };
    # Write settings to a seperate file so that optionInclude can override others settings
    constructFiles.userConfig =
      if config."config.toml".content or "" != "" then
        {
          relPath = "${config.binName}.toml";
          content = config."config.toml".content;
        }
      else
        {
          relPath = "${config.binName}-user-config.toml";
          builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
          content = builtins.toJSON config.settings;
        };

    constructFiles.generatedConfig = {
      relPath = "${config.binName}.toml";
      builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      content = builtins.toJSON {
        include = {
          files = [ config.constructFiles.userConfig.path ];
          optional.files = config.includeOptional;
        };
      };
    };
    systemd.user.service.umbriel = lib.mkIf config.enableConfigHotReload {
      Unit.X-Reload-Triggers = [ "${config.constructFiles.generatedConfig.path}" ];
      Service = {
        ExecReload = "${lib.getExe config.package} config-replace ${config.constructFiles.generatedConfig.path}";
        X-ReloadIfChanged = true;
      };
    };
    passthru.providedSessions = config.package.passthru.providedSessions or [ "umbriel" ];
    meta.maintainers = [ wlib.maintainers.WinterMaximus ];
    meta.platforms = lib.platforms.linux;
  };
}
