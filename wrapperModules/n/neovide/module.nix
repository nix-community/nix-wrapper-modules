{
  config,
  lib,
  wlib,
  pkgs,
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
      default = {};
      description = ''
        Configuration passed to neovide using the `NEOVIDE_CONFIG` environment variable.
        See <https://neovide.dev/config-file.html> for the config options.
      '';
    };
    config = {
      package = pkgs.neovide;
      env.NEOVIDE_CONFIG = "${config.binDir}/config.toml";
      constructFiles.generatedConfig = {
        content = builtins.toJSON config.settings;
        relPath = "${config.binDir}/config.toml";
        builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      };
      meta.maintainers = [ wlib.maintainers.nuclear-squid ];
    };
  };
}
