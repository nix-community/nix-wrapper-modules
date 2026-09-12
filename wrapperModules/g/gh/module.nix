{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
let
  yamlFormat = pkgs.formats.yaml { };
  inherit (lib) mkOption;
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = mkOption {
      inherit (yamlFormat) type;
      default = { };
      description = ''
        Configuration that goes to {file}`config.yml`
      '';
    };
  };
  config = {
    package = lib.mkDefault pkgs.gh;
    env = {
      GH_CONFIG_DIR = "${placeholder config.outputName}/gh-config";
    };
    drv = {
      configYml = yamlFormat.generate "config.yml" config.settings;
      buildPhase = ''
        runHook preBuild
        mkdir -p "${placeholder config.outputName}/gh-config"
        cp "$configYml" "${placeholder config.outputName}/gh-config/config.yml"
        runHook postBuild
      '';
    };
    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
