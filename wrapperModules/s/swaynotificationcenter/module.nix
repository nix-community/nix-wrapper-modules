{
  config,
  lib,
  wlib,
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
      type = wlib.types.structuredValueWith { typeName = "JSON"; };

      default = { };

      description = ''
        SwayNotificationCenter configuration settings.
        See https://github.com/ErikReider/SwayNotificationCenter#configuring
      '';

      example = {
        widgets = [
          "title"
          "dnd"
          "mpris"
          "volume"
          "backlight"
          "buttons-grid"
          "notifications"
        ];
      };
    };

    stylesheet = lib.mkOption {
      type = lib.types.lines;

      default = "";

      description = "CSS style for SwayNotificationCenter.";
    };
  };

  config = {
    package = lib.mkDefault pkgs.swaynotificationcenter;

    constructFiles.generatedConfig = {
      content = builtins.toJSON config.settings;
      relPath = "${config.binName}-config.json";
    };

    constructFiles.generatedStyle = {
      content = config.stylesheet;
      relPath = "${config.binName}-style.css";
    };

    systemd.user.service.swaync = {
      overwrite = true;

      Unit = {
        Description = "Swaync notification daemon";
        Documentation = [ "https://github.com/ErikReider/SwayNotificationCenter" ];
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
        X-Restart-Triggers = [ config.constructFiles.generatedConfig.path ];
      };

      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = config.wrapperPaths.placeholder;
        ExecReload = "${config.wrapperPaths.placeholder} --reload-config ; ${config.wrapperPaths.placeholder} --reload-css";
        Restart = "on-failure";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    flags = {
      "--config" = config.constructFiles.generatedConfig.path;
      "--style" = config.constructFiles.generatedStyle.path;
    };

    meta.maintainers = [ wlib.maintainers.leafayon ];

    meta.platforms = lib.platforms.linux;
  };
}
