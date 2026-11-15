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
      type = wlib.types.structuredValueWith {
        nullable = false;
        typeName = "TOML";
      };
      default = { };
      description = ''
        Configuration of ashell.
        See <https://malpenzibo.github.io/ashell/docs/configuration>
      '';
    };
    systemdTarget = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = "Systemd target to bind to. Set to null to disable systemd integration.";
    };
  };
  config.flags."--config-path" = config.constructFiles.generatedConfig.path;
  config.constructFiles.generatedConfig = {
    content = builtins.toJSON config.settings;
    relPath = "${config.binName}-config.toml";
    builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
  };
  config.systemd.user.service.ashell = lib.mkIf (config.systemdTarget != null) {
    overwrite = true;
    Install.WantedBy = [ config.systemdTarget ];
    Unit = {
      Description = "A ready to go status bar for Wayland compositors";
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
  config.package = lib.mkDefault pkgs.ashell;
  config.meta.maintainers = [ wlib.maintainers.aliaslion ];
}
