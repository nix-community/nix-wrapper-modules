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
      type = wlib.types.yamlValue;
      default = { };
      description = ''
        Configuration of ov.
        See <https://github.com/noborus/ov/blob/master/ov.yaml>
      '';
    };
  };
  config.flags = {
    "--config" = config.constructFiles.generatedConfig.path;
  };
  config.constructFiles.generatedConfig = {
    format = "yaml";
    value = config.settings;
    relPath = "${config.binName}-config.yaml";
  };
  config.package = lib.mkDefault pkgs.ov;
  config.meta.maintainers = [ wlib.maintainers.rencire ];
}
