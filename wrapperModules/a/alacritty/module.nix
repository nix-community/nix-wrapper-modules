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
      type = wlib.types.tomlValue;
      default = { };
      description = ''
        Configuration of alacritty.
        See {manpage}`alacritty(5)` or <https://alacritty.org/config-alacritty.html>
      '';
    };
  };
  config.flags."--config-file" = config.constructFiles.generatedConfig.path;
  config.constructFiles.generatedConfig = {
    format = "toml";
    value = config.settings;
    relPath = "${config.binName}-config.toml";
  };
  config.package = lib.mkDefault pkgs.alacritty;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
