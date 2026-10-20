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
  };
  config = {
    package = lib.mkDefault pkgs.direnv;
    env = {
      # We currently do not inject `DIRENV_CONFIG` for the reasons outlined in
      # meta.description.pre.

      # **IMPORTANT** Using `placeholder "out"` here seems to cause issues if this wrapper is
      # built inside a subWrapperModule (for example within the zshWrapper) as it refers
      # to the build zsh output in that context. The passthru variants seems to solve this issue.
      DIRENV_CONFIG = "${placeholder "out"}/${config.configDirname}";
    };
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
      **IMPORTANT** In order to use this wrapper, `DIRENV_CONFIG` needs to be explicitly 
      set in your shells environment:

      ```shell
      DIRENV_CONFIG="''${direnvWrapper.passthru.DIRENV_CONFIG}"
      ```

      This is because right now, direnv will use the original `direnv` binary in its shell hook
      and not the wrapper script. So injecting `DIRENV_CONFIG` currently has no effect.

      If the PR below will ever be merged, this issue can be fixed by setting:

      ```nix
      env.DIRENV_EXE_PATH = "''${placeholder "out"}/bin/direnv";
      ```

      This would make the direnv hook use the wrapper instead of the original binary and 
      injecting `DIRENV_CONFIG` into the wrapper would start to take effect. 

      https://github.com/direnv/direnv/pull/1564
    '';
  };
}
