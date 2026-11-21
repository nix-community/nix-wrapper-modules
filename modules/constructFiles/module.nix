{
  config,
  lib,
  wlib,
  ...
}@top:
{
  options.constructFiles = lib.mkOption {
    description = ''
      An option for creating files with content of arbitrary length in the final wrapper derivation,
      in which the nix placeholders like `''${placeholder "out"}` can be used
    '';
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        {
          config,
          options,
          name,
          ...
        }:
        {
          config.outPath =
            if config.relPath == "" then
              "${top.config.wrapper.${config.output}}"
            else
              "${top.config.wrapper.${config.output}}/${config.relPath}";
          config.path =
            if config.relPath == "" then
              "${placeholder config.output}"
            else
              "${placeholder config.output}/${config.relPath}";
          options = {
            key = lib.mkOption {
              type = wlib.types.nonEmptyLine;
              default = name;
              description = ''
                The attribute to add the file contents to on the final derivation

                If you get an error like "config.jsonPath: invalid variable name",
                then that means you should set this value
                to something which is a valid shell variable name.
              '';
              apply = wlib.sanitizeEnvVarName;
            };
            format = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.enum [
                  "json"
                  "toml"
                  "yaml"
                ]
              );
              default = null;
              description = ''
                Generate the file from `value` in the given format.

                When set, `content` defaults to `builtins.toJSON value`,
                and `builder` defaults to a `remarshal` command which converts
                that JSON into the requested format.

                Both `content` and `builder` may still be overridden.
              '';
            };
            value = lib.mkOption {
              type =
                if config.format == null then
                  wlib.types.structuredValueWith { typeName = "serializable"; }
                else
                  {
                    json = wlib.types.jsonValue;
                    toml = wlib.types.tomlValue;
                    yaml = wlib.types.yamlValue;
                  }
                  .${config.format};
              default = { };
              description = ''
                The value to serialize when `format` is set. Ignored otherwise.

                Attribute sets are merged recursively and lists are concatenated.
                `null` is allowed, except when `format = "toml"`.
              '';
            };
            content = lib.mkOption {
              type = lib.types.lines;
              default =
                if config.format != null then
                  builtins.toJSON config.value
                # `value` was defined by someone (any priority above the option's own default)
                else if options.value.highestPrio < (lib.mkOptionDefault null).priority then
                  throw ''constructFiles.${name}: `value` is set but `format` is null; set `format` to "json", "toml" or "yaml".''
                else
                  "";
              defaultText = lib.literalExpression ''if format == null then "" else builtins.toJSON value'';
              description = ''
                The content for the file to be added to the final derivation
              '';
            };
            output = lib.mkOption {
              type = wlib.types.nonEmptyLine;
              default = top.config.outputName;
              description = ''
                The output the generated file will be created in.
              '';
            };
            outPath = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              description = "The path to the output file available from outside of the wrapper module";
            };
            path = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              description = "The path to the output file available from inside of the wrapper module";
            };
            relPath = lib.mkOption {
              type = lib.types.str;
              description = ''
                relative output path within the named output to create the file (no leading slash)
              '';
            };
            passAsContent = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                This option controls the value passed as `$1` to the `.builder` command

                If false, `$1` will contain the path to the input file

                If true, `$1` will contain the content of the input file

                It is recommended to use `true` when `config.drv.__structuredAttrs = true`
                and `false` otherwise for performance,
                unless you specifically need one or the other for your `.builder` command.
              '';
            };
            builder = lib.mkOption {
              type = lib.types.str;
              default =
                let
                  remarshal = tool: "${top.config.pkgs.remarshal}/bin/${tool}";
                  convert =
                    tool:
                    if config.passAsContent then
                      ''printf '%s' "$1" | ${remarshal tool} - "$2"''
                    else
                      ''${remarshal tool} "$1" "$2"'';
                in
                if config.format == "toml" then
                  convert "json2toml"
                else if config.format == "yaml" then
                  convert "json2yaml"
                else if config.passAsContent then
                  ''echo "$1" > "$2"''
                else
                  ''cp "$1" "$2"'';
              defaultText = lib.literalMD ''
                - `format = "toml"`: `json2toml` from `pkgs.remarshal`
                - `format = "yaml"`: `json2yaml` from `pkgs.remarshal`
                - otherwise: `cp "$1" "$2"` (or `echo "$1" > "$2"` when `passAsContent = true`)
              '';
              description = ''
                the command used to build the file.

                Will be placed inside a bash function,
                with $1 as the input file and $2 as the output file
              '';
            };
          };
        }
      )
    );
  };
  config.drv = lib.mkIf (config.constructFiles != { }) (
    let
      files = builtins.attrValues config.constructFiles;
      mkUnique =
        attrs: base:
        let
          try =
            i:
            let
              candidate = if i == null then base else "${base}_${toString i}";
            in
            if attrs ? ${candidate} then try (if i == null then 0 else i + 1) else candidate;
        in
        try null;
      result =
        builtins.foldl'
          (
            acc: v:
            let
              key = mkUnique acc.attrs v.key;
            in
            {
              attrs = acc.attrs // {
                ${key} = v.content;
              };
              passAsFile = acc.passAsFile ++ [ key ];
            }
          )
          {
            attrs = {
              # prevents something from being named this
              passAsFile = [ ];
            };
            passAsFile = [ ];
          }
          files;
    in
    result.attrs // { inherit (result) passAsFile; }
  );
  config.buildCommand.constructFiles = {
    before = [
      "makeWrapper"
      "symlinkScript"
    ];
    data =
      let
        constructFile = name: path: builder: asContent: /* bash */ ''
          constructFile() {
            ${builder}
          }
          mkdir -p "$(dirname ${lib.escapeShellArg path})"
          if [ -n "$__structuredAttrs" ]; then
            ${
              if asContent then # bash
                ''constructFile "''$${name}" ${lib.escapeShellArg path}''
              # bash
              else
                ''
                  local tempfile="$(mktemp)"
                  echo "''$${name}" > "$tempfile"
                  constructFile "$tempfile" ${lib.escapeShellArg path}
                ''
            }
          else
            ${
              if asContent then
                # bash
                ''constructFile "''$${name}" ${lib.escapeShellArg path}''
              else
                # bash
                ''
                  local sourceDrvVarToConstruct=${lib.escapeShellArg "${name}Path"}
                  constructFile "''${!sourceDrvVarToConstruct}" ${lib.escapeShellArg path}
                ''
            }
          fi
        '';
      in
      ''
        # create constructFiles
        ${lib.optionalString (config.constructFiles != { }) (
          lib.pipe config.constructFiles [
            builtins.attrValues
            (map (
              {
                path,
                builder,
                key,
                passAsContent,
                ...
              }:
              constructFile key path builder passAsContent
            ))
            (
              v:
              [ "constructFile(){" ]
              ++ v
              ++ [
                "}"
                "constructFile"
                "unset -f constructFile"
              ]
            )
            (builtins.concatStringsSep "\n")
          ]
        )}
      '';
  };
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config.meta.description = ''
    Adds a `constructFiles` option that allows for easier creation of generated files in which placeholders such as `''${placeholder "out"}` work

    From inside the module, you can

    ```nix
    config.constructFiles.<name> = {
      content = "some file content";
      relPath = "some/path";
    };
    # you can get the resulting placeholder path with config.constructFiles.<name>.path
    ```

    It also provides a read-only config value that allows the placeholder file location to be easily accessible outside of the derivation.

    In addition, on the resulting package, all the values in config are accessible via `passthru.configuration`

    This means you can `yourWrappedPackage.configuration.constructFiles.<name>.outPath` to get the final path to it from outside of the wrapper module,
    without having to worry about making sure placeholders resolve correctly yourself.

    Note, that will not work inside the module. Inside the module, you will want to use `config.constructFiles.<name>.path`.

    Also note that attribute sets with `.outPath` in them can be directly interpolated.

    Outside the module, you can also get the path with `"''${yourWrappedPackage.configuration.constructFiles.<name>}"`

    Imported by `wlib.modules.default`
  '';
}
