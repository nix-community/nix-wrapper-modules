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
    syntaxes = lib.mkOption {
      type = lib.types.attrsOf wlib.types.stringable;
      default = { };
      description = ''
        Paths of bat/sublime syntaxes to symnlink to `syntaxes/` directory
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
      env.BAT_CONFIG_DIR = "${placeholder "out"}/${config.binName}-config";
      constructFiles = {
        generatedConfig = {
          content = config.configFile.content;
          relPath = "${config.binName}-config/config";
        };
      }
      // themes-constructFiles;
      buildCommand.makeBatSyntaxes =
        "mkdir -p ${placeholder "out"}/syntaxes\n"
        + lib.concatMapAttrsStringSep "\n" (
          name: value: "ln -s ${value} ${placeholder "out"}/syntaxes/${name}"
        ) config.syntaxes;
      meta.maintainers = [ wlib.maintainers.appleptree ];
    };
}
