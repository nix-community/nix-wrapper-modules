let
  options_module =
    _file: excluded: is_top:
    {
      config,
      options,
      wlib,
      lib,
      mainConfig ? null,
      mainOpts ? null,
      ...
    }@top:
    let
      runtimeExtrasType =
        pathname:
        (
          wlib.types.dalOf
          // {
            modules = [
              {
                options.prefix = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Place this value at the beginning of the `${pathname}` instead of the end.
                  '';
                };
              }
            ];
            dontConvertFunctions = true;
          }
        )
          wlib.types.stringable;
      extraPath = lib.pipe (config.runtimePkgs or [ ]) [
        (wlib.dag.unwrapSort "runtimePkgs")
        (builtins.partition (v: v.prefix or false == true))
        (
          { right, wrong }:
          {
            pre = map (v: v.data) right;
            post = map (v: v.data) wrong;
          }
        )
      ];
      extraLibs = lib.pipe (config.runtimeLibs or [ ]) [
        (wlib.dag.unwrapSort "runtimeLibs")
        (builtins.partition (v: v.prefix or false == true))
        (
          { right, wrong }:
          {
            pre = map (v: v.data) right;
            post = map (v: v.data) wrong;
          }
        )
      ];
      optionalAttribute =
        name:
        let
          isExcluded = v: builtins.isBool v && v;
        in
        if
          isExcluded (excluded.${name} or false)
          || (is_top && isExcluded (excluded.top.${name} or false))
          || (!is_top && isExcluded (excluded.wrapperVariants.${name} or false))
        then
          null
        else
          name;
    in
    {
      inherit _file;
      options.${optionalAttribute "argv0type"} = lib.mkOption {
        type =
          with lib.types;
          either (enum [
            "resolve"
            "inherit"
          ]) (functionTo str);
        default =
          if mainConfig != null && config.mirror or false then
            mainConfig.argv0type or "inherit"
          else
            "inherit";
        description = ''
          `argv0` overrides this option if not null or unset

          Both `shell` and the `nix` implementations
          ignore this option, as the shell always resolves `$0`

          However, the `binary` implementation will use this option

          Values:

          - `"inherit"`:

          The executable inherits argv0 from the wrapper.
          Use instead of `--argv0 '$0'`.

          - `"resolve"`:

          If argv0 does not include a "/" character, resolve it against PATH.

          - Function form: `str -> str`

          This one works only in the nix implementation. The others will treat it as `inherit`

          Rather than calling exec, you get the command plus all its flags supplied,
          and you can choose how to run it.

          e.g. `command_string: "eval \"$(''${command_string})\";`

          It will also be added to the end of the overall `DAL`,
          with the name `NIX_RUN_MAIN_PACKAGE`

          Thus, you can make things run after it,
          but by default it is still last.
        '';
      };
      options.${optionalAttribute "argv0"} = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = if mainConfig != null && config.mirror or false then mainConfig.argv0 or null else null;
        description = ''
          --argv0 NAME

          Set the name of the executed process to NAME.
          If unset or null, defaults to EXECUTABLE.

          overrides the setting from `argv0type` if set.
        '';
      };
      options.${optionalAttribute "unsetVar"} = lib.mkOption {
        type = wlib.types.dalWithEsc lib.types.str;
        default = if mainConfig != null && config.mirror or false then mainConfig.unsetVar or [ ] else [ ];
        description = ''
          --unset VAR

          Remove VAR from the environment.
        '';
      };
      options.${optionalAttribute "runShell"} = lib.mkOption {
        type = wlib.types.dalWithEsc wlib.types.stringable;
        default = if mainConfig != null && config.mirror or false then mainConfig.runShell or [ ] else [ ];
        description = ''
          --run COMMAND

          Run COMMAND before executing the main program.

          This option takes a list.

          Any entry can instead be of type `{ data, name ? null, before ? [], after ? [], esc-fn ? null }`

          This will cause it to be added to the DAG.

          If no name is provided, it cannot be targeted.
        '';
      };
      options.${optionalAttribute "chdir"} = lib.mkOption {
        type = wlib.types.dalWithEsc wlib.types.stringable;
        default = if mainConfig != null && config.mirror or false then mainConfig.chdir or [ ] else [ ];
        description = ''
          --chdir DIR

          Change working directory before running the executable.
          Use instead of `--run "cd DIR"`.
        '';
      };
      options.${optionalAttribute "addFlag"} = lib.mkOption {
        type = wlib.types.wrapperFlag;
        default = if mainConfig != null && config.mirror or false then mainConfig.addFlag or [ ] else [ ];
        example = lib.literalMD ''
          ```nix
          [
            "-v"
            "-f"
            [
              "--config"
              ./storePath.cfg
            ]
            [
              "-s"
              "idk"
            ]
          ]
          ```
        '';
        description = ''
          Wrapper for

          --add-flag ARG

          Prepend the single argument ARG to the invocation of the executable,
          before any command-line arguments.

          This option takes a list. To group them more strongly,
          option may take a list of lists as well.

          Any entry can instead be of type `{ data, name ? null, before ? [], after ? [], esc-fn ? null }`

          This will cause it to be added to the DAG.

          If no name is provided, it cannot be targeted.
        '';
      };
      options.${optionalAttribute "appendFlag"} = lib.mkOption {
        type = wlib.types.wrapperFlag;
        default =
          if mainConfig != null && config.mirror or false then mainConfig.appendFlag or [ ] else [ ];
        example = lib.literalMD ''
          ```nix
          [
            "-v"
            "-f"
            [
              "--config"
              ./storePath.cfg
            ]
            [
              "-s"
              "idk"
            ]
          ]
          ```
        '';
        description = ''
          --append-flag ARG

          Append the single argument ARG to the invocation of the executable,
          after any command-line arguments.

          This option takes a list. To group them more strongly,
          option may take a list of lists as well.

          Any entry can instead be of type `{ data, name ? null, before ? [], after ? [], esc-fn ? null }`

          This will cause it to be added to the DAG.

          If no name is provided, it cannot be targeted.
        '';
      };
      options.${optionalAttribute "prefixVar"} = lib.mkOption {
        type = wlib.types.wrapperFlags 3;
        default = if mainConfig != null && config.mirror or false then mainConfig.prefixVar or [ ] else [ ];
        example = lib.literalMD ''
          ```nix
          [
            [
              "LD_LIBRARY_PATH"
              ":"
              "''${lib.makeLibraryPath (with pkgs; [ ... ])}"
            ]
            [
              "PATH"
              ":"
              "''${lib.makeBinPath (with pkgs; [ ... ])}"
            ]
          ]
          ```
        '';
        description = ''
          --prefix ENV SEP VAL

          Prefix ENV with VAL, separated by SEP.
        '';
      };
      options.${optionalAttribute "suffixVar"} = lib.mkOption {
        type = wlib.types.wrapperFlags 3;
        default = if mainConfig != null && config.mirror or false then mainConfig.suffixVar or [ ] else [ ];
        example = lib.literalMD ''
          ```nix
          [
            [
              "LD_LIBRARY_PATH"
              ":"
              "''${lib.makeLibraryPath (with pkgs; [ ... ])}"
            ]
            [
              "PATH"
              ":"
              "''${lib.makeBinPath (with pkgs; [ ... ])}"
            ]
          ]
          ```
        '';
        description = ''
          --suffix ENV SEP VAL

          Suffix ENV with VAL, separated by SEP.
        '';
      };
      options.${optionalAttribute "prefixContent"} = lib.mkOption {
        type = wlib.types.wrapperFlags 3;
        default =
          if mainConfig != null && config.mirror or false then mainConfig.prefixContent or [ ] else [ ];
        description = ''
          ```nix
          [
            [ "ENV" "SEP" "FILE" ]
          ]
          ```

          Prefix ENV with contents of FILE and SEP at build time.

          Also accepts sets like the other options

          ```nix
          [
            [ "ENV" "SEP" "FILE" ]
            { data = [ "ENV" "SEP" "FILE" ]; esc-fn = lib.escapeShellArg; /* name, before, after */ }
          ]
          ```
        '';
      };
      options.${optionalAttribute "suffixContent"} = lib.mkOption {
        type = wlib.types.wrapperFlags 3;
        default =
          if mainConfig != null && config.mirror or false then mainConfig.suffixContent or [ ] else [ ];
        description = ''
          ```nix
          [
            [ "ENV" "SEP" "FILE" ]
          ]
          ```

          Suffix ENV with SEP and then the contents of FILE at build time.

          Also accepts sets like the other options

          ```nix
          [
            [ "ENV" "SEP" "FILE" ]
            { data = [ "ENV" "SEP" "FILE" ]; esc-fn = lib.escapeShellArg; /* name, before, after */ }
          ]
          ```
        '';
      };
      options.${optionalAttribute "flags"} = lib.mkOption {
        type =
          with lib.types;
          (
            wlib.types.dagOf
            // {
              dontConvertFunctions = true;
              modules = wlib.types.dagWithEsc.modules ++ [
                {
                  options.sep = lib.mkOption {
                    type = nullOr str;
                    default = null;
                    description = ''
                      A per-item override of the default separator used for flags and their values
                    '';
                  };
                  options.ifs = lib.mkOption {
                    type = nullOr str;
                    default = null;
                    description = ''
                      If `null`, and a list is provided, the key-value pairs will be repeated.

                      If a string is provided, it will instead be the key, followed by the main separator,
                      followed by the list joined with this value as the separator.


                      `flags."--myflag" = { ifs = null; sep = "="; data = [ "a" "b" "c" ]; }`

                      will result in

                      `--myflag=a --myflag=b --myflag=c`

                      `flags."--myflag" = { ifs = ","; sep = "="; data = [ "a" "b" "c" ]; }`

                      will result in

                      `--myflag=a,b,c`
                    '';
                  };
                }
              ];
            }
          )
            (
              nullOr (oneOf [
                bool
                wlib.types.stringable
                (listOf wlib.types.stringable)
              ])
            );
        default = if mainConfig != null && config.mirror or false then mainConfig.flags or { } else { };
        example = lib.literalMD ''
          ```nix
          {
            "--config" = ./nixPath;
          }
          ```
        '';
        description = ''
          Flags to pass to the wrapper.
          The key is the flag name, the value is the flag value.
          If the value is true, the flag will be passed without a value.
          If the value is false or null, the flag will not be passed.
          If the value is a list, the flag will be passed multiple times with each value.

          This option takes a set.

          Any entry can instead be of type `{ data, before ? [], after ? [], esc-fn ? null, sep ? null, ifs ? null }`

          The `sep` field may be used to override the value of `config.flagSeparator`

          The `ifs` field is relevant when your value is a list.

          `flags."--myflag" = { ifs = null; sep = "="; data = [ "a" "b" "c" ]; }`

          will result in

          `--myflag=a --myflag=b --myflag=c`

          `flags."--myflag" = { ifs = ","; sep = "="; data = [ "a" "b" "c" ]; }`

          will result in

          `--myflag=a,b,c`
        '';
      };
      options.${optionalAttribute "flagSeparator"} = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default =
          if mainConfig != null && config.mirror or false then mainConfig.flagSeparator or null else null;
        description = ''
          Separator between flag names and values when generating args from flags.
          `" "` for `--flag value` or `"="` for `--flag=value`

          If null (the default), they will always be separate, sequential arguments,
          even if not interpolated by a shell (such as with the `"binary"` implementation)
        '';
      };
      options.${optionalAttribute "runtimePkgs"} = lib.mkOption {
        type = runtimeExtrasType "PATH";
        default =
          if mainConfig != null && config.mirror or false then mainConfig.runtimePkgs or [ ] else [ ];
        description = ''
          Additional packages to add to the wrapper's runtime PATH.
          This is useful if the wrapped program needs additional libraries or tools to function correctly.

          Accepts a list of either packages, or set of `{ data, prefix ? false, name ? null, before ? [], after ? [] }`
          where the `data` field is the package.

          Adds suffixed entries to the DAG under the name `NIX_PATH_ADDITIONS`
          Adds prefixed entries to the DAG under the name `NIX_PATH_PREFIXES`
        '';
      };
      options.${optionalAttribute "runtimeLibs"} = lib.mkOption {
        type = runtimeExtrasType "LD_LIBRARY_PATH";
        default =
          if mainConfig != null && config.mirror or false then mainConfig.runtimeLibs or [ ] else [ ];
        description = ''
          Additional libraries to add to the wrapper's runtime LD_LIBRARY_PATH.
          This is useful if the wrapped program needs additional libraries or tools to function correctly.

          Accepts a list of either packages, or set of `{ data, prefix ? false, name ? null, before ? [], after ? [] }`
          where the `data` field is the package.

          Adds suffixed entries to the DAG under the name `NIX_LIB_ADDITIONS`
          Adds prefixed entries to the DAG under the name `NIX_LIB_PREFIXES`
        '';
      };
      config.${
        if excluded.runtimePkgs or false && excluded.runtimeLibs or false then null else "suffixVar"
      } =
        lib.optional (extraPath.post != [ ]) {
          name = "NIX_PATH_ADDITIONS";
          data = [
            "PATH"
            ":"
            "${lib.makeBinPath extraPath.post}"
          ];
        }
        ++ lib.optional (extraLibs.post != [ ]) {
          name = "NIX_LIB_ADDITIONS";
          data = [
            "LD_LIBRARY_PATH"
            ":"
            "${lib.makeLibraryPath extraLibs.post}"
          ];
        };
      config.${
        if excluded.runtimePkgs or false && excluded.runtimeLibs or false then null else "prefixVar"
      } =
        lib.optional (extraPath.pre != [ ]) {
          name = "NIX_PATH_PREFIXES";
          data = [
            "PATH"
            ":"
            "${lib.makeBinPath extraPath.pre}"
          ];
        }
        ++ lib.optional (extraLibs.pre != [ ]) {
          name = "NIX_LIB_PREFIXES";
          data = [
            "LD_LIBRARY_PATH"
            ":"
            "${lib.makeLibraryPath extraLibs.pre}"
          ];
        };
      options.${optionalAttribute "env"} = lib.mkOption {
        type = wlib.types.dagWithEsc (lib.types.nullOr wlib.types.stringable);
        default = if mainConfig != null && config.mirror or false then mainConfig.env or { } else { };
        example = {
          "XDG_DATA_HOME" = "/somewhere/on/your/machine";
        };
        description = ''
          Environment variables to set in the wrapper.

          This option takes a set.

          Any entry can instead be of type `{ data, before ? [], after ? [], esc-fn ? null }`

          This will cause it to be added to the DAG,
          which will cause the resulting wrapper argument to be sorted accordingly
        '';
      };
      options.${optionalAttribute "envDefault"} = lib.mkOption {
        type = wlib.types.dagWithEsc (lib.types.nullOr wlib.types.stringable);
        default =
          if mainConfig != null && config.mirror or false then mainConfig.envDefault or { } else { };
        example = {
          "XDG_DATA_HOME" = "/only/if/not/set";
        };
        description = ''
          Environment variables to set in the wrapper.

          Like env, but only adds the variable if not already set in the environment.

          This option takes a set.

          Any entry can instead be of type `{ data, before ? [], after ? [], esc-fn ? null }`

          This will cause it to be added to the DAG,
          which will cause the resulting wrapper argument to be sorted accordingly
        '';
      };
      options.${optionalAttribute "escapingFunction"} = lib.mkOption {
        type = lib.types.functionTo lib.types.str;
        default =
          if mainConfig != null && config.mirror or false then
            mainConfig.escapingFunction or lib.escapeShellArg
          else
            lib.escapeShellArg;
        defaultText = lib.literalExpression "lib.escapeShellArg";
        description = ''
          The function to use to escape shell values

          Caution: When using `shell` or `binary` implementations,
          these will be expanded at BUILD time.

          You should probably leave this as is when using either of those implementations.

          However, when using the `nix` implementation, they will expand at runtime!
          Which means `wlib.escapeShellArgWithEnv` may prove to be a useful substitute!
        '';
      };
      options.${optionalAttribute "wrapperImplementation"} = lib.mkOption {
        type = lib.types.enum [
          "nix"
          "shell"
          "binary"
        ];
        default =
          if mainConfig != null && config.mirror or false then
            mainConfig.wrapperImplementation or "nix"
          else
            "nix";
        description = ''
          the `nix` implementation is the default

          It makes the `escapingFunction` most relevant.

          This is because the `shell` and `binary` implementations
          use `pkgs.makeWrapper` or `pkgs.makeBinaryWrapper`,
          and arguments to these functions are passed at BUILD time.

          So, generally, when not using the nix implementation,
          you should always prefer to have `escapingFunction`
          set to `lib.escapeShellArg`.

          However, if you ARE using the `nix` implementation,
          using `wlib.escapeShellArgWithEnv` will allow you
          to use `$` expansions, which will expand at runtime.

          `binary` implementation is useful for programs
          which are likely to be used in "shebangs",
          as macos will not allow scripts to be used for these.

          However, it is more limited. It does not have access to
          `runShell`, `prefixContent`, and `suffixContent` options.

          Chosing `binary` will thus cause values in those options to be ignored.
        '';
      };
      config._module.args = {
        mainConfig = null;
        mainOpts = null;
      };
      options.${if is_top then optionalAttribute "wrapperVariants" else null} = lib.mkOption {
        default = { };
        description = ''
          Allows for you to apply the wrapper options to multiple binaries from config.package (or elsewhere)

          They are called variants because they are the same options as the top level makeWrapper options,
          however, their defaults mirror the values of the top level options.

          Meaning if you set `config.env.MYVAR = "HELLO"` at the top level,
          then the following statement would be true by default:

          `config.wrapperVariants.foo.env.MYVAR.data == "HELLO"`

          They achieve this by receiving `mainConfig` and `mainOpts` via `specialArgs`,
          which contain `config` and `options` from the top level.
        '';
        type = lib.types.attrsOf (
          lib.types.submoduleWith {
            specialArgs = {
              mainConfig = config;
              mainOpts = options;
              inherit wlib;
            };
            modules = [
              (options_module _file excluded false)
              (
                { name, config, ... }:
                {
                  inherit _file;
                  options.enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = ''
                      Enables the wrapping of this variant
                    '';
                  };
                  options.mirror = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = ''
                      Allows the variant to inherit defaults from the top level
                    '';
                  };
                  options.exePath = lib.mkOption {
                    type = lib.types.nullOr wlib.types.nonEmptyLine;
                    default = "${top.config.binDir}/${name}";
                    description = ''
                      The location within the package of the thing to wrap.
                    '';
                  };
                  options.binName = lib.mkOption {
                    type = wlib.types.nonEmptyLine;
                    default = name;
                    description = ''
                      The name of the file to output to `''${placeholder config.outputName}''${config.wrapperPaths.relDir}`
                    '';
                  };
                  options.binDir = lib.mkOption {
                    type = lib.types.nullOr wlib.types.nonEmptyLine;
                    default = top.config.binDir or "bin";
                    description = ''
                      the directory the wrapped result will be placed into, with the name indicated by the `binName` option

                      i.e. `"''${placeholder outputName}/<THIS_VALUE>/''${binName}"`
                    '';
                  };
                  options.outputName = lib.mkOption {
                    type = wlib.types.nonEmptyLine;
                    default = top.config.outputName or "out";
                    description = ''
                      The derivation output the wrapped binary will be placed into.
                    '';
                  };
                  options.wrapperPaths = {
                    input = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      default = "${config.package}" + lib.optionalString (config.exePath != null) "/${config.exePath}";
                      description = "
                            The path which is to be wrapped by the wrapperFunction implementation
                          ";
                    };
                    placeholder = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      default = "${placeholder config.outputName or "out"}${config.wrapperPaths.relPath}";
                      description = "
                            The path which the wrapperFunction implementation is to output its result to.
                          ";
                    };
                    relPath = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      default =
                        config.wrapperPaths.relDir + lib.optionalString (config.binName != "") "/${config.binName}";
                      description = ''
                        The binary will be output to `''${placeholder config.outputName}''${config.wrapperPaths.relPath}`
                      '';
                    };
                    relDir = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      default = lib.optionalString (config.binDir != null) "/${config.binDir}";
                      description = ''
                        The binary will be output to `''${placeholder config.outputName}''${config.wrapperPaths.relDir}/''${config.binName}`
                      '';
                    };
                  };
                  options.package = lib.mkOption {
                    type = wlib.types.stringable;
                    default = top.config.package;
                    description = ''
                      The package to wrap with these options
                    '';
                  };
                }
              )
            ];
          }
        );
      };
    };
in
{
  wrapperFunction = null;
  # excluded_options.argv0 = true;  # both top & variants
  # excluded_options.top.argv0 = true;  # just top
  # excluded_options.wrapperVariants.argv0 = true;  # just variants
  excluded_options = { };
  exclude_wrapper = false;
  exclude_meta = false;
  _file = ./module.nix;
  key = ./module.nix;
  __functor =
    self:
    {
      config,
      lib,
      wlib,
      pkgs,
      # NOTE: makes sure builderFunction and wrapperFunction get name from _module.args
      options,
      extendModules,
      name ? null,
      ...
    }@args:
    {
      _file = self._file or ./module.nix;
      ${if (self.key or ./module.nix) != null then "key" else null} = self.key or ./module.nix;
      imports = [ (options_module (self._file or ./module.nix) (self.excluded_options or { }) true) ];
      options.${
        if
          builtins.isBool (self.excluded_options.wrapperFunction or null)
          && self.excluded_options.wrapperFunction
        then
          null
        else
          "wrapperFunction"
      } =
        lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          default =
            if self.wrapperFunction or null != null then self.wrapperFunction else wlib.makeWrapper.wrapAll;
          description = ''
            Arguments:

            This option takes a function receiving the following arguments:

            module arguments + `pkgs.callPackage`

            ```
            {
              config,
              wlib,
              ... # <- anything you can get from pkgs.callPackage
            }
            ```
            This is the function used to process the wrapper arguments.

            By default, it is `wlib.makeWrapper.wrapAll`

            It will be called with the normal module arguments + `pkgs.callPackage` arguments

            The module calls it, and places the result in `config.buildCommand.makeWrapper` with `lib.mkOptionDefault` priority.

            The relative path to the thing to wrap is `config.wrapperPaths.input`

            This function is to return a string of build commands which create a result at `config.wrapperPaths.placeholder`
          '';
        };
      config.${if self.exclude_wrapper or false then null else "buildCommand"}.makeWrapper = {
        before = [ "symlinkScript" ];
        data = lib.mkOptionDefault (
          let
            res = pkgs.callPackage (
              if
                builtins.isBool (self.excluded_options.wrapperFunction or null)
                && self.excluded_options.wrapperFunction
              then
                wlib.makeWrapper.wrapAll
              else
                config.wrapperFunction
            ) args;
          in
          if builtins.isString res then
            res
          else
            throw ''
              Returning something other than a build command string from wrapperFunction is no longer supported.

              To pass other values to `builderFunction`, place them in an option.
            ''
        );
      };
      config.${if self.exclude_meta or false then null else "meta"} = {
        maintainers = [ wlib.maintainers.birdee ];
        description = {
          pre = ''
            An implementation of the `makeWrapper` interface via type safe module options.

            Allows you to choose one of several underlying implementations of the `makeWrapper` interface.

            Imported by `wlib.modules.default`

            Wherever the type includes `DAG` you can mentally substitute this with `attrsOf`

            Wherever the type includes `DAL` or `DAG list` you can mentally substitute this with `listOf`

            However they also take items of the form `{ data, name ? null, before ? [], after ? [] }`

            This allows you to specify that values are added to the wrapper before or after another value.

            The sorting occurs across ALL the options, thus you can target items in any `DAG` or `DAL` within this module from any other `DAG` or `DAL` option within this module.

            The `DAG`/`DAL` entries in this module also accept an extra field, `esc-fn ? null`

            If defined, it will be used instead of the value of `options.escapingFunction` to escape that value.

            It also has a set of submodule options under `config.wrapperVariants` which allow you
            to duplicate the effects to other binaries from the package, or add extra ones.

            Each one contains an `enable` option, and a `mirror` option.

            They also contain the same options the top level module does, however if `mirror` is `true`,
            as it is by default, then they will inherit the defaults from the top level as well.

            They also have their own `package`, `exePath`, and `binName` options, with sensible defaults.

            ---
          '';
          post = ''
            ---

            ## Modify this module before import

            Should you ever need to redefine `config.wrapperFunction`, you might have slightly different options!

            `makeWrapper = import wlib.modules.makeWrapper;`

            If you import it like shown, you gain the ability to modify it.

            You may `//` (update) the following values into the set you gain from importing the file:

            `exclude_wrapper = true;` to stop it from setting `config.buildCommand.makeWrapper`

            `wrapperFunction = ...;` to override the default `config.wrapperFunction` that it sets instead of excluding it.

            `exclude_meta = true;` to stop it from setting any values in `config.meta`

            `excluded_options = { ... };` where you may include `optionname = true`
            in order to not define that option.

            You may also scope exclusions to just the top level or just variants:

            ```nix
            excluded_options.top.argv0 = true;              # only top
            excluded_options.wrapperVariants.argv0 = true;  # only variants
            excluded_options.argv0 = true;                  # both
            ```

            `_file` and `key`: `_file` changes the value set for the modules imported when you import this module. `key` is set on the main one if not `null`.

            In order to change these values, you change them in the set before importing the module like so:

            ```nix
              imports = [ (import wlib.modules.makeWrapper // { excluded_options.wrapperVariants = true; }) ];
            ```
          '';
        };
      };
    };
}
