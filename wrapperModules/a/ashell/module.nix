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
      default = { };
      description = ''
        Configuration of ashell.
        See <https://malpenzibo.github.io/ashell/docs/configuration>
      '';
    };
  };
  config.flags."--config-path" = config.constructFiles.generatedConfig.path;
  config.constructFiles.generatedConfig = {
    content = builtins.toJSON config.settings;
    relPath = "${config.binName}-config.toml";
    builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
  };
  config.package = lib.mkDefault pkgs.ashell;
  config.meta.maintainers = [ wlib.maintainers.aliaslion ];
}
