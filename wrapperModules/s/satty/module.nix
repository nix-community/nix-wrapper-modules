{
  pkgs,
  config,
  wlib,
  lib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = wlib.types.structuredValueWith {
        nullable = false;
        typeName = "TOML";
      };

      default = { };

      description = ''
        Satty configuration options.
        See <https://satty-org.github.io/Satty/usage/config/> for reference.
      '';

      example = {
        general = {
          fullscreen = true;
          copy-command = "wl-copy";
          actions-on-enter = [ "save-to-clipboard" ];
        };

        color-palette = {
          palette = [
            "#00ffff"
            "#a52a2a"
            "#dc143c"
            "#ff1493"
            "#ffd700"
            "#008000"
          ];
        };
      };
    };
  };

  config = {
    flags."--config" = config.constructFiles.generatedConfig.path;
    constructFiles.generatedConfig = {
      content = builtins.toJSON config.settings;
      relPath = "${config.binName}-config.toml";
      builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };

    package = lib.mkDefault pkgs.satty;

    meta = {
      maintainers = [ wlib.maintainers.szymon-jozef ];
      platforms = lib.platforms.linux;
    };
  };
}
