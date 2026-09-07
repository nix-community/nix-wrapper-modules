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
        Configuration of iamb.
        See {manpage}`iamb(5)` or <https://iamb.chat/configure.html>

        Note: at least one profile is required for startup.
      '';
      example.profiles.myuser.user_id = "@user:example.com";
    };
  };
  config.package = lib.mkDefault pkgs.iamb;
  config.flags."--config-directory" = dirOf (dirOf config.constructFiles.config.path);
  config.passthru.generatedConfig = dirOf (dirOf config.constructFiles.config.outPath);
  config.constructFiles.config = {
    relPath = "${config.binName}-config/iamb/config.toml";
    content = builtins.toJSON config.settings;
    builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
  };
  config.meta.maintainers = [ wlib.maintainers.aliaslion ];
}
