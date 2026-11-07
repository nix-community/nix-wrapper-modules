{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = wlib.types.hyprConfValue;
      default = { };
      example = lib.literalExpression ''
        {
          general = {
            grace = 5;
            hide_cursor = true;
            ignore_empty_input = true;
          };

          background = [
            {
              path = "screenshot";
              blur_passes = 3;
              blur_size = 8;
            }
          ];

          input-field = [
            {
              size = "200, 50";
              position = "0, -80";
              monitor = "";
              dots_center = true;
              fade_on_empty = false;
            }
          ];
        }
      '';
      description = ''
        Configuration for Hyprlock.
        See <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock>
      '';
    };

    "hyprlock.conf" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
        content = (
          lib.optionalString (config.settings != { }) (
            wlib.toHyprconf {
              inherit (config) importantPrefixes;
              attrs = config.settings;
            }
          )
          + lib.optionalString (config.extraConfig != "") config.extraConfig
        );
      };
      default = { };
      description = ''
        Hyprlock configuration file.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        source = /path/to/extra.conf
      '';
      description = ''
        Extra configuration lines appended to the end of
        the Hyprlock configuration file.
      '';
    };

    importantPrefixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "$"
        "bezier"
        "monitor"
        "size"
      ];
      example = [
        "$"
        "bezier"
      ];
      description = ''
        List of prefix strings whose matching configuration entries
        are placed at the top of the generated configuration file.
      '';
    };
  };

  config.package = lib.mkDefault pkgs.hyprlock;
  config.flags."--config" = config."hyprlock.conf".path;

  config.constructFiles.generatedConfig = {
    content = config."hyprlock.conf".content;
    relPath = "${config.binName}.conf";
  };

  config.meta = {
    maintainers = [ wlib.maintainers.nouritsu ];
    platforms = lib.platforms.linux;
  };
}
