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

  componentType = types.lazyAttrsOf (
    types.oneOf [
      wlib.types.linkable
      types.lines
      (componentType // { description = "nested components"; })
    ]
  );
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
    info = lib.mkOption {
      type =
        lib.types.addCheck wlib.types.attrsRecursive (
          x: builtins.all (n: builtins.match "^[a-zA-Z_][a-zA-Z0-9_]*$" n != null) (builtins.attrNames x)
        )
        // {
          description = "qml property with json content";
        };
      default = { };
      description = ''
        This option allows you to pass information to the quickshell configuration separate from the configuration file/directory.

        If you override the `config.configDir` option, you will no longer be able to pass qml code from nix easily, in exchange for being able to simply provide a normal quickshell directory to the module.

        But you may still wish to pass information to the configuration from nix.

        In your qml files, you may use `import NixInfo` and then `NixInfo.your.value` from the values passed to this info option.

        The name `NixInfo` is also configurable with the `infoModuleName` option.

        The top level keys in this attribute set must be valid qml property names. Keys nested further may be any string, as they are represented as qml properties with json values.

        This module will be made available to the qml quickshell configuration regardless of how the configuration directory is specified.
      '';
    };
    infoModuleName = lib.mkOption {
      type = lib.types.str;
      default = "NixInfo";
      description = "Configures the importable name for the generated qml info module";
    };
  };

  config.prefixVar = [
    [
      "QML2_IMPORT_PATH"
      ":"
      "${dirOf (dirOf config.constructFiles.nixInfo.path)}"
    ]
  ];

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
              value = if isStringLike v then toString v else v;

              # Auto capitalization for qml files or inlined text
              attrIsFile = builtins.isString v || (isLinkable v && lib.hasSuffix ".qml" value);

              firstChar = builtins.substring 0 1 name;
              restChars = builtins.substring 1 (-1) name;
              finalName =
                if !attrIsFile then
                  name
                else
                  (lib.toUpper firstChar) + restChars + lib.optionalString (!lib.hasSuffix ".qml" name) ".qml";
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
      nixInfoQmlDir = {
        relPath = makeForce (dirOf config.constructFiles.nixInfo.relPath + "/qmldir");
        output = makeForce config.constructFiles.nixInfo.output;
        content = ''
          module ${config.infoModuleName}
          singleton ${config.infoModuleName} 1.0 ${config.infoModuleName}.qml
        '';
      };
      nixInfo = {
        relPath = "qml-path-dirs/${config.infoModuleName}/${config.infoModuleName}.qml";
        output = config.generated.output;
        content = /* qml */ ''
          pragma Singleton
          import QtQml
          QtObject {
            ${lib.pipe config.info [
              (lib.mapAttrsToList (n: v: "readonly property var ${n}: (${builtins.toJSON v})"))
              (builtins.concatStringsSep "\n  ")
            ]}
          }
        '';
      };
    };

  config.meta.maintainers = [ wlib.maintainers.ormoyo ];
  config.meta.platforms = lib.platforms.linux;
}
