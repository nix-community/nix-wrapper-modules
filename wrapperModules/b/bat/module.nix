{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    configFile = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default.content = "";
      description = ''
        Bat flags to include via config file
      '';
    };
    themes = lib.mkOption {
      type = lib.types.attrsOf (wlib.types.file pkgs);
      default = { };
      description = ''
        Bat themes to copy to `themes/` directory
      '';
    };
  };

  config =
    let
      themes-constructFiles = lib.concatMapAttrs (name: value: {
        "themes-${name}" = {
          content = builtins.readFile value.path;
          relPath = "themes/${name}";
        };
      }) config.themes;
    in
    {
      package = lib.mkDefault pkgs.bat;
      env.BAT_CONFIG_DIR = "${placeholder "out"}/${config.binName}-config/themes";
      constructFiles = {
        generatedConfig = {
          content = config.configFile.content;
          relPath = "${config.binName}-config/config";
        };
      }
      // themes-constructFiles;
      meta.maintainers = [ wlib.maintainers.appleptree ];
    };
}
