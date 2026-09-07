{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  inherit (lib)
    isStringLike
    mapAttrs
    mkDefault
    mkIf
    mkOption
    types
    ;

  isLinkable = wlib.types.linkable.check;
  makeForce = lib.mkOverride 0;

  componentType = types.submodule {
    freeformType = types.lazyAttrsOf (
      types.oneOf [
        wlib.types.linkable
        types.lines
        (componentType // { description = "nested components"; })
      ]
    );
  };
in
{
  imports = [ wlib.modules.default ];
  options = {
    configFile = mkOption {
      type = types.either wlib.types.linkable types.lines;
      default = "";
      description = ''
        The quickshell shell.qml configuration file.

        Provide either inlined configuration or reference an external file.
      '';
    };
    configDir = mkOption {
      type = wlib.types.linkable;
      default = config.generated.placeholder;
      description = ''
        The full quickshell configuration directory.

        It is passed to quickshell using `--path`.
      '';
    };
    components = mkOption {
      type = componentType;
      default = { };
      description = "Quickshell components to include in the configuration";
      example = lib.literalExpression ''
        {
          some.path."Bar.qml" = ./some-widget.qml;
          light.clock = '''
            Text {
              text: "hello world"
            }
          ''';
          dark.clock = "/etc/quickshell/Clock.qml";
          lockscreensDir =
            let
              repo = pkgs.fetchFromGitHub {
                owner = "Darkkal44";
                repo = "qylock";
                rev = "cde4d11e9e3d385620becdc877a0521e40a55e47";
                hash = "sha256-17kRwrkdfe+hJdChMxove73zNCKcSi0nmSrO8Fh8hz0=";
              };
            in
            "''${repo}/quickshell-lockscreen";
        }
      '';
    };
    generated.output = mkOption {
      type = types.str;
      default = config.outputName;
      description = "The constructed file's output";
    };
    generated.placeholder = mkOption {
      type = types.str;
      readOnly = true;
      default = "${placeholder config.generated.output}/${config.binName}-config";
      description = "A placeholder for the generated config dir";
    };
  };

  config.package = mkDefault pkgs.quickshell;
  config.flags."--path" = config.configDir;

  config.passthru.generatedConfigDir = "${
    config.wrapper.${config.generated.output}
  }/${config.binName}-config";

  config.constructFiles =
    let
      getComponents' =
        prefix: val:
        if builtins.isAttrs val then
          lib.foldlAttrs (
            acc: name: v:
            let
              value = if isStringLike v then builtins.toString v else v;

              # Auto capitalization for qml files or inlined text
              attrIsFile = builtins.isString v || (isStringLike v && lib.hasSuffix ".qml" value);

              firstChar = builtins.substring 0 1 name;
              restChars = builtins.substring 1 (-1) name;
              finalName = if !attrIsFile then name else (lib.toUpper firstChar) + restChars + ".qml";
            in
            acc // getComponents' (prefix + "/" + finalName) value
          ) { } val
        else
          { ${prefix} = val; };
      getComponents = getComponents' "";
    in
    (mapAttrs (name: value: {
      content = mkIf (!isLinkable value) value;
      builder = mkIf (isLinkable value) ''ln -s ${value} "$2"'';
      output = makeForce config.generated.output;
      relPath = makeForce "${config.binName}-config${name}";
    }) (getComponents config.components))
    // {
      generatedConfig = {
        content = mkIf (!isLinkable config.configFile) config.configFile;
        builder = mkIf (isLinkable config.configFile) ''ln -s ${config.configFile} "$2"'';
        output = makeForce config.generated.output;
        relPath = makeForce "${config.binName}-config/shell.qml";
      };
    };

  config.meta.maintainers = [ wlib.maintainers.ormoyo ];
  config.meta.platforms = lib.platforms.linux;
}
