{
  config,
  pkgs,
  wlib,
  lib,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type = wlib.types.structuredValueWith { typeName = "JSON"; };
      default = { };
      description = "Sets OPENCODE_CONFIG for github:sst/opencode";
    };
    tui-settings = lib.mkOption {
      type = wlib.types.structuredValueWith { typeName = "JSON"; };
      default = { };
      description = "Sets OPENCODE_TUI_CONFIG for github:sst/opencode";
    };
  };
  config = {
    meta.maintainers = [
      wlib.maintainers.birdee
      wlib.maintainers.lodwkobku
    ];
    package = lib.mkDefault pkgs.opencode;
    envDefault = {
      OPENCODE_CONFIG = config.constructFiles.opencodeConfig.path;
      OPENCODE_TUI_CONFIG = config.constructFiles.opencodeTuiConfig.path;
    };
    constructFiles = {
      opencodeConfig = {
        relPath = "${config.binName}-config.json";
        content = builtins.toJSON config.settings;
      };
      opencodeTuiConfig = {
        relPath = "${config.binName}-tui-config.json";
        content = builtins.toJSON config.tui-settings;
      };
    };
  };
}
