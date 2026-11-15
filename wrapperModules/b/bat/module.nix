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
    settings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          bool
          number
          wlib.types.stringable
          (listOf (either number wlib.types.stringable))
        ]);
      default = { };
      description = ''
        Bat cli flags mapped to bat configuration file.

        The names of single character flags will be prepended with `-`

        The names of longer flags will be prepended with `--`

        Including `false` as the value will cause it not to be included.

        Including `true` as the value will cause it to print only its name.

        Include a list of values to repeat the flag.
      '';
      example = {
        theme-dark = "TwoDark";
        theme = "dark";
        numbers = true;
      };
    };
    themes = lib.mkOption {
      type = lib.types.attrsOf wlib.types.linkable;
      default = { };
      description = ''
        Paths of bat/sublime themes to symlink to `themes/` directory

        Note that while the name here specifies the directory name,
        the name of the theme is the name of the `.tmTheme` file inside.

        Unless you have `preBakeCache` set to true (which is the default value),
        you also may have to run `bat cache --build` the first time for the theme to work.
      '';
    };
    syntaxes = lib.mkOption {
      type = lib.types.attrsOf wlib.types.linkable;
      default = { };
      description = ''
        Paths of bat/sublime syntaxes to symnlink to `syntaxes/` directory

        Unless you have `preBakeCache` set to true (which is the default value),
        you also may have to run `bat cache --build` the first time for the syntax to be installed.
      '';
    };
    preBakeCache = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Make the cache at build time and store it in the derivation.

        This removes the need to use `bat cache --build` to use the themes from this module

        This also removes the ability to run `bat cache --build` or `bat cache --clear` at runtime.

        Set this to false if you need to use an impure path for a theme or syntax to edit it and see feedback.
      '';
    };
  };

  config =
    let
      cfgdir = dirOf config.constructFiles.generatedConfig.path;
    in
    {
      package = lib.mkDefault pkgs.bat;
      env.BAT_CONFIG_DIR = cfgdir;
      passthru.BAT_CONFIG_DIR = dirOf config.constructFiles.generatedConfig.outPath;
      constructFiles.generatedConfig = {
        content = lib.pipe config.settings [
          (lib.mapAttrsToList lib.nameValuePair)
          (builtins.concatMap (
            { value, ... }@v:
            let
              name = if builtins.stringLength v.name == 1 then "-${v.name}" else "--${v.name}";
            in
            if builtins.isBool value then
              lib.optional value name
            else if builtins.isList value then
              map (v: [ "${name} ${lib.escapeShellArg v}" ]) value
            else
              [ "${name} ${lib.escapeShellArg value}" ]
          ))
          (builtins.concatStringsSep "\n")
        ];
        relPath = "${config.binName}-config/config";
      };
      buildCommand.makeBatSyntaxes =
        "mkdir -p ${cfgdir}/syntaxes\n"
        + lib.concatMapAttrsStringSep "\n" (
          name: value: "ln -s ${value} ${cfgdir}/syntaxes/${name}"
        ) config.syntaxes;
      buildCommand.makeBatThemes =
        "mkdir -p ${cfgdir}/themes\n"
        + lib.concatMapAttrsStringSep "\n" (
          name: value: "ln -s ${value} ${cfgdir}/themes/${name}"
        ) config.themes;
      env.BAT_CACHE_PATH = lib.mkIf config.preBakeCache "${placeholder config.constructFiles.generatedConfig.output}/${config.binName}-cache";
      buildCommand.preBakeCache = lib.mkIf config.preBakeCache {
        after = [
          "makeBatSyntaxes"
          "makeBatThemes"
          "makeWrapper"
          "constructFiles"
          "symlinkScript"
          "runStdenvPhases"
        ];
        data = ''
          ${config.wrapperPaths.placeholder} cache --build
        '';
      };
      meta.maintainers = [ wlib.maintainers.appleptree ];
    };
}
