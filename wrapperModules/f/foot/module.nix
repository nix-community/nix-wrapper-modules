{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  iniOptions = {
    listsAsDuplicateKeys = true;
    mkKeyValue =
      with lib.generators;
      mkKeyValueDefault {
        mkValueString =
          v:
          mkValueStringDefault { } (
            if v == true then
              "yes"
            else if v == false then
              "no"
            else if v == null then
              "none"
            else
              v
          );
      } "=";
  };

  iniFmt = pkgs.formats.ini iniOptions;
in
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      inherit (iniFmt) type;
      default = { };
      description = ''
        Configuration of foot terminal.
        See {manpage}`foot.ini(5)`
      '';
    };
  };
  config.flags."--config" = config.constructFiles.generatedConfig.path;
  config.constructFiles.generatedConfig = {
    content = lib.generators.toINI iniOptions config.settings;
    relPath = "${config.binName}.ini";
  };
  config.filesToPatch = [ "share/systemd/user/*.service" ];
  config.package = lib.mkDefault pkgs.foot;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config.meta.platforms = lib.platforms.linux;
}
