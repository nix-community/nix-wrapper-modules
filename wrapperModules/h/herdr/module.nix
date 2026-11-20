{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:

let
  tomlFmtType = wlib.types.structuredValueWith {
    nullable = false;
    typeName = "TOML";
  };
in
{
  imports = [ wlib.modules.default ];

  options.settings = lib.mkOption {
    type = tomlFmtType;
    default = { };
    description = ''
      Herdr configuration options.
      See the Herdr documentation for available options.
    '';
  };

  config = {
    package = lib.mkDefault pkgs.herdr;

    env.HERDR_CONFIG_PATH = config.constructFiles.generatedConfig.path;
    passthru.HERDR_CONFIG_PATH = config.constructFiles.generatedConfig.path;

    constructFiles.generatedConfig = {
      content = builtins.toJSON config.settings;
      relPath = "${config.binName}/config.toml";
      builder = ''
        ${pkgs.remarshal}/bin/json2toml "$1" "$2"
      '';
    };

    settings.onboarding = lib.mkDefault false;

    meta = {
      maintainers = [ wlib.maintainers.pimkoter ];
      description.pre = ''
        This wrapper provides a separate configuration file for Herdr, configured through the settings option.
        Note that only the configuration file path is overridden; Herdr's other runtime files, such as logs,
        snapshots, and sockets, are still stored in ~/.config/herdr.
        Since Herdr does not support loading configuration from multiple locations, 
        changes made through the TUI settings menu will not be reflected in the wrapper-managed configuration. 
        Additionally, the onboarding prompt is disabled by default, as settings configured through it would not be applied.
        For this reason onboarding is disabled by default.
      '';
    };
  };
}
