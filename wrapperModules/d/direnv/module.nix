{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };
  direnvDotdir = "${config.wrapper.${config.outputName}}/${config.configDirname}";
  # Since 2.38.1, the direnv shell hook respects `DIRENV_EXE_PATH`.
  # See https://github.com/direnv/direnv/pull/1564
  supportsExePath = lib.versionAtLeast config.package.version "2.38.1";
in
{
  imports = [ wlib.modules.default ];
  options = {
    configDirname = lib.mkOption {
      type = lib.types.str;
      default = "${config.binName}-dot-dir";
      description = "Name of the directory which is created as the dotdir in the wrapper output";
    };
    silent = lib.mkEnableOption "silent mode, that is, disabling direnv logging";
    direnvrc = lib.mkOption {
      type = lib.types.lines;
      description = "Content of `$DIRENV_CONFIG/direnv`";
      default = "";
    };
    nix-direnv = {
      enable = lib.mkEnableOption "nix-direnv integration";
      package = lib.mkPackageOption pkgs "nix-direnv" { };
    };
    mise = {
      enable = lib.mkEnableOption "mise integration";
      package = lib.mkPackageOption pkgs "mise" { };
    };
    lib = lib.mkOption {
      type = with lib.types; attrsOf lines;
      description = ''
        Configuration of [extension files](https://direnv.net/#the-stdlib) 
        that will be created at `$DIRENV_CONFIG/lib/*.sh`
      '';
      example = {
        "my-lib-script.sh" = "echo 'content of my-lib-script.sh'";
      };
      default = { };
    };
    extraConfig = lib.mkOption {
      inherit (tomlFmt) type;
      default = { };
      description = ''
        Configuration of direnv.toml.
        See <https://direnv.net/man/direnv.toml.1.html>
      '';
    };
    warnIfLegacyVersion = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to emit a warning when direnv < 2.38.1 is used, reminding you that
        `DIRENV_CONFIG` needs to be set in your shell's environment.
        See the description of this module for details.
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.direnv;
    env =
      if supportsExePath then
        {
          DIRENV_CONFIG = "${placeholder "out"}/${config.configDirname}";
          DIRENV_EXE_PATH = "${placeholder "out"}/bin/direnv";
        }
      else
        # For direnv < 2.38.1 the shell hook calls the unwrapped binary and thus ignores the
        # wrapper's environment. We deliberately do not inject `DIRENV_CONFIG` in that case,
        # as it would only apply to direct invocations (e.g. `direnv exec`) and not to the
        # hook, leading to inconsistent behavior. See meta.description.pre.
        lib.warnIf config.warnIfLegacyVersion ''
          nix-wrapper-modules direnv: direnv ${config.package.version} < 2.38.1 is used.
          With this version, the direnv shell hook will not pick up the wrapper's configuration.
          We recommend using direnv 2.38.1 or newer. If that is not possible, set `DIRENV_CONFIG`
          in your shell's rc file as a workaround:

            DIRENV_CONFIG="''${direnvWrapper.passthru.DIRENV_CONFIG}"

          To silence this warning, set `warnIfLegacyVersion = false;` in the direnv wrapper.
        '' { };
    # Unlike `env.DIRENV_CONFIG` (which uses `placeholder "out"`), this resolves to the
    # wrapper's actual store path, so it can safely be used by other derivations.
    passthru.DIRENV_CONFIG = direnvDotdir;
    lib = {
      "nix-direnv.sh" = lib.mkIf config.nix-direnv.enable ''
        source ${config.nix-direnv.package}/share/nix-direnv/direnvrc
      '';
      "mise.sh" = lib.mkIf config.mise.enable ''
        eval "$(${lib.getExe config.mise.package} direnv activate)"
      '';
    };
    extraConfig = {
      global = lib.mkIf (config.silent) {
        log_format = "-";
        log_filter = "^$";
      };
    };
    constructFiles = {
      direnvToml = {
        content = builtins.toJSON config.extraConfig;
        relPath = "${config.configDirname}/direnv.toml";
        builder = ''mkdir -p "$(dirname "$2")" && ${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      };
      direnvRc = {
        content = config.direnvrc;
        relPath = "${config.configDirname}/direnvrc";
      };
    }
    // lib.mapAttrs (name: value: {
      content = value;
      relPath = "${config.configDirname}/lib/${name}";
    }) config.lib;
    meta.maintainers = [ wlib.maintainers.zenoli ];
    meta.description.pre = ''
      We recommend using direnv 2.38.1 for the best experience.

      From that version on, the wrapper sets
      `DIRENV_EXE_PATH` so that the direnv shell hook calls the wrapper itself, and
      `DIRENV_CONFIG` is injected automatically. No extra shell configuration is needed.

      `DIRENV_EXE_PATH` support was added in direnv 2.38.1 via
      [direnv/direnv#1564](https://github.com/direnv/direnv/pull/1564).

      **Workaround for older versions:** if you cannot use a recent direnv, set `DIRENV_CONFIG`
      in your shell's rc file instead:

      ```shell
      DIRENV_CONFIG="''${direnvWrapper.passthru.DIRENV_CONFIG}"
      ```

      This is needed because older direnv versions call the original `direnv` binary in their
      shell hook rather than the wrapper, so the hook ignores the wrapper's environment.
      The wrapper emits a warning in that case, which can be silenced with
      `warnIfLegacyVersion = false`.
    '';
  };
}
