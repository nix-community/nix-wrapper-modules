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

    filesToPatch = [
      "share/systemd/user/*.service"
    ];

    systemd.user.service.swaync.Unit.X-Restart-Triggers = [
      config.constructFiles.generatedConfig.path
      config.constructFiles.generatedStyle.path
    ];

    flags = {
      "--config" = config.constructFiles.generatedConfig.path;
      "--style" = config.constructFiles.generatedStyle.path;
    };

    meta.maintainers = [ wlib.maintainers.leafayon ];

    meta.platforms = lib.platforms.linux;
  };
}
