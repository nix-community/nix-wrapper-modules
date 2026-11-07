{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    wlib.modules.default
    wlib.modules.systemd
  ];

  options = {
    settings = lib.mkOption {
      type = wlib.types.hyprConfValue;
      default = { };
      example = lib.literalExpression ''
        {
          general = {
            after_sleep_cmd = "hyprctl dispatch dpms on";
            ignore_dbus_inhibit = false;
            lock_cmd = "hyprlock";
          };

          listener = [
            {
              timeout = 900;
              on-timeout = "hyprlock";
            }
            {
              timeout = 1200;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ];
        }
      '';
      description = ''
        Configuration for Hypridle.
        See <https://wiki.hypr.land/Hypr-Ecosystem/hypridle>
      '';
    };

    "hypridle.conf" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
        content =
          lib.optionalString (config.settings != { }) (
            wlib.toHyprconf {
              inherit (config) importantPrefixes;
              attrs = config.settings;
            }
          )
          + lib.optionalString (config.extraConfig != "") config.extraConfig;
      };
      default = { };
      description = ''
        Hypridle configuration file.
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
        the Hypridle configuration file.
      '';
    };

    importantPrefixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "$"
      ];
      example = [
        "$"
      ];
      description = ''
        List of prefix strings whose matching configuration entries
        are placed at the top of the generated configuration file.
      '';
    };

    systemdTarget = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = "Systemd target to bind to.";
    };
  };

  config = {
    package = lib.mkDefault pkgs.hypridle;
    flags."--config" = config."hypridle.conf".path;

    constructFiles.generatedConfig = {
      content = config."hypridle.conf".content;
      relPath = "${config.binName}.conf";
    };

    systemd.user.service.hypridle = {
      overwrite = true;
      Install = {
        WantedBy = [ config.systemdTarget ];
      };
      Unit = {
        Description = "Hyprland's idle daemon";
        ConditionEnvironment = "WAYLAND_DISPLAY";
        After = [ config.systemdTarget ];
        PartOf = [ config.systemdTarget ];
        X-Restart-Triggers = [ config.constructFiles.generatedConfig.path ];
      };
      Service = {
        ExecStart = config.wrapperPaths.placeholder;
        Restart = "on-failure";
      };
    };

    meta = {
      maintainers = [ wlib.maintainers.jonas-elhs ];
      platforms = lib.platforms.linux;
    };
  };
}
