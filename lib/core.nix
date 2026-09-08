{
  options,
  config,
  lib,
  wlib,
  extendModules,
  moduleType,
  _prefix ? [ ],
  # NOTE: makes sure builderFunction gets name from _module.args
  name ? null,
  ...
}@args:
let
  descriptionsWithFiles =
    let
      opts = {
        pre = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "header text";
        };
        post = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "footer text";
        };
      };
    in
    lib.mkOptionType {
      name = "descriptionsWithFiles";
      check = (lib.types.either lib.types.str (lib.types.submodule { options = opts; })).check;
      descriptionClass = "noun";
      description = ''string or { pre ? "", post ? "" } (converted to `[ { pre, post, file } ]`)'';
      merge =
        loc: defs:
        (lib.types.listOf (
          lib.types.submodule {
            options = opts // {
              file = lib.mkOption {
                type = wlib.types.stringable;
                description = "file";
              };
            };
          }
        )).merge
          loc
          (
            map (
              v:
              v
              // {
                value =
                  if builtins.isString v.value then
                    [
                      {
                        inherit (v) file;
                        pre = v.value;
                      }
                    ]
                  else
                    [ (v.value // { inherit (v) file; }) ];
              }
            ) defs
          );
    };
  maintainersWithFiles =
    let
      maintainer = lib.types.submodule (
        { name, ... }:
        {
          freeformType = wlib.types.attrsRecursive;
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "name";
            };
            github = lib.mkOption {
              type = lib.types.str;
              description = "GitHub username";
            };
            githubId = lib.mkOption {
              type = lib.types.int;
              description = "GitHub id";
            };
            email = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "email";
            };
            matrix = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Matrix ID";
            };
            file = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              internal = true;
              visible = false;
            };
          };
        }
      );
      withFiles =
        elemType:
        let
          name = "maintainersWithFiles";
          base = lib.types.listOf elemType;
        in
        lib.mkOptionType {
          inherit name;
          inherit (base)
            check
            description
            descriptionClass
            getSubOptions
            getSubModules
            ;
          substSubModules = m: withFiles (elemType.substSubModules m);
          merge = {
            __functor =
              self: loc: defs:
              (self.v2 { inherit loc defs; }).value;
            v2 =
              { loc, defs }:
              base.merge.v2 {
                inherit loc;
                defs = (
                  map (
                    def:
                    def
                    // {
                      value = map (
                        def':
                        def'
                        // {
                          inherit (def) file;
                        }
                      ) def.value;
                    }
                  ) defs
                );
              };
          };
        };
    in
    withFiles maintainer;
in
{
  config.meta.description = ''
    These are the core options that make everything else possible.

    They include the `.extendModules`, `.apply`, `.eval`, and `.wrap` functions, and the `.wrapper` itself

    They are always imported with every module evaluation.

    They are somewhat minimal by design. They pertain to building the derivation, not the wrapper script.

    The default `builderFunction` value is `{ buildCommand, ... }: buildCommand;`,
    which just runs the result of `buildCommand`, and the non-problematic stdenv phases by default

    `buildCommand` is also empty by default.

    `wlib.modules.default` provides great starting values for these options, and creates many more for you to use.

    But you may want to wrap your package via different means, provide different options, or provide modules for others to use to help do those things!

    Doing it this way allows wrapper modules to do anything you might wish involving wrapping some source/package in a derivation.

    Excited to see what ways to use these options everyone comes up with! Docker helpers? BubbleWrap? If it's a derivation, it should be possible!

    ---
  '';
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config._module.args.pkgs = config.pkgs;
  config.install.modules = {
    homeManager =
      { config, ... }:
      {
        config.home.packages =
          let
            cfg = args.config.install.getWrapperConfig config;
          in
          lib.mkIf cfg.enable [ cfg.wrapper ];
      };
    hjem =
      { config, ... }:
      {
        config.packages =
          let
            cfg = args.config.install.getWrapperConfig config;
          in
          lib.mkIf cfg.enable [ cfg.wrapper ];
      };
    nixos =
      { config, ... }:
      {
        config.environment.systemPackages =
          let
            cfg = args.config.install.getWrapperConfig config;
          in
          lib.mkIf cfg.enable [ cfg.wrapper ];
      };
    darwin =
      { config, ... }:
      {
        config.environment.systemPackages =
          let
            cfg = args.config.install.getWrapperConfig config;
          in
          lib.mkIf cfg.enable [ cfg.wrapper ];
      };
  };
  options = {
    install = lib.mkOption {
      description = ''
        This submodule contains options which create a generic integration module.

        You can then import this submodule as a module in the module systems you specify in `config.install.modules`

        i.e. in nixos or home manager `{ imports = [ inputs.nix-wrapper-modules.wrappers.<name>.install ]; }`

        home manager, nixos, and nix darwin will by default also install the package.

        It will create the options at `config.install.optionLocation`

        This will default to `[ "wrappers" (lib.last _prefix) ]`,
        so before importing it like this you will want to either set `config.install.optionLocation` yourself,
        or use `wlib.getInstallModule` to set prefix before importing the module.

        In this way, your wrapper module can specify installation instructions for any module system evaluation which sets the `class` attribute
      '';
      type = lib.types.submodule (
        { config, ... }:
        {
          _file = wlib.core;
          options = {
            optionLocation = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = lib.optionals (_prefix != [ ]) [
                "wrappers"
                (lib.last _prefix)
              ];
              description = ''
                The location for the generated submodule option containing the wrapper module

                This will be set for you if you use the provided flake-parts module or `wlib.getInstallModule`, otherwise you must set it manually.

                This is to prevent the option location depending on the `pkgs` of the target evaluation, as it would if we used `config.binName`.
              '';
            };
            mkWrapperExtension = lib.mkOption {
              type = lib.types.functionTo lib.types.raw;
              readOnly = true;
              default =
                key: module:
                lib.setAttrByPath config.optionLocation {
                  imports = lib.toList module;
                  key = builtins.unsafeDiscardStringContext "${wlib.core}:${
                    if lib.isStringLike module then "${module}." else ""
                  }install.mkWrapperExtension:${toString key}";
                };
              description = ''
                Function that takes a wrapper module to place at the path indicated by `config.install.optionLocation`.

                It then returns the set to pass to config within an `install.modules` option

                To provide this alongside the config for the target module system, you can use `lib.mkMerge`

                ```nix
                { ... }@top: { # <- in a wrapper module
                  config.install.modules.nixos = { config, pkgs, lib, ... }: {
                    config = lib.mkMerge [
                      # pass another wrapper module
                      # but available for only this module system (nixos in this example)
                      (top.config.install.mkWrapperExtension "unique key name" (
                        { wlib, pkgs, lib, config, ... }: {
                          options.enableService = lib.mkEnableOption "installation of service units";
                        }
                      ))
                      # config for nixos module (in this example)
                      {
                        systemd.packages = let
                          # get the config from the wrapper modules option namespace
                          cfg = top.config.install.getWrapperConfig config;
                        in lib.mkIf cfg.enableService [ cfg.wrapper ];
                      }
                    ];
                  };
                }
                ```

                Tip: Instead of using `mkWrapperExtension`, you might wish to consider simply declaring the option in the wrapper module,
                and just checking its value when relevant in your `install.modules` modules

                This function is generally most useful when the option declaration itself must know something about the target module system.
              '';
            };
            getWrapperConfig = lib.mkOption {
              type = lib.types.functionTo lib.types.raw;
              default =
                let
                  res = lib.attrByPath config.optionLocation null;
                in
                if res == null then
                  throw "could not find the wrapper config! `getWrapperConfig` works only in the modules exported by `<this_wrapper_module>.install` and the configurations which import it!"
                else
                  res;
              readOnly = true;
              description = ''
                This option indexes into config and returns the wrapper submodule at `config.install.optionLocation` within it

                ```nix
                { ... }@top: { # <- in a wrapper module
                  config.install.modules.nixos = { config, lib, ... }: let
                    wrappercfg = top.config.install.getWrapperConfig config;
                  in {
                    config = lib.mkIf wrappercfg.enable {
                      # ...
                    };
                  };
                }
                ```
              '';
            };
            modules = lib.mkOption {
              type = lib.types.lazyAttrsOf lib.types.deferredModule;
              # don't set default, instead set via config, so that you can add some default behavior to some of them
              description = ''
                A set of modules for integrating the wrapper module with an external module system. Place a module at the attribute name corresponding with the class of the target module evaluation
              '';
            };
            __functor = lib.mkOption {
              type = lib.types.raw;
              internal = true;
              readOnly = true;
              default =
                _:
                {
                  _class,
                  pkgs ? null,
                  ...
                }:
                {
                  _file = wlib.core;
                  imports = lib.toList (config.modules.${_class} or [ ]);
                  options =
                    assert
                      config.optionLocation != [ ]
                      || throw "to import `<wrapper_module>.install`, you must set `config.install.optionLocation` to a non-empty list of strings!";
                    lib.setAttrByPath config.optionLocation (
                      lib.mkOption {
                        type = moduleType;
                        default = { };
                      }
                    );
                  config = config.mkWrapperExtension "wrappers-install-add-enable-option" {
                    _file = wlib.core;
                    config._module.args.name = lib.mkOverride (lib.modules.defaultOverridePriority - 1) (
                      lib.last config.optionLocation
                    );
                    options.enable = lib.mkEnableOption "the wrapper module.";
                    config.pkgs = lib.mkIf (pkgs != null) pkgs;
                  };
                };
            };
          };
        }
      );
    };
    meta = {
      maintainers = lib.mkOption {
        description = "Maintainers of this module.";
        type = maintainersWithFiles;
        default = [ ];
      };
      platforms = lib.mkOption {
        type = (lib.types.listOf (lib.types.enum lib.platforms.all)) // {
          description = "list of strings from enum of lib.platforms.all";
        };
        example = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        default = lib.platforms.all;
        defaultText = lib.literalExpression "lib.platforms.all";
        description = "Supported platforms";
      };
      description = lib.mkOption {
        description = ''
          Description of the module.

          Accepts either a string, or a set of `{ pre ? "", post ? "" }`

          Resulting config value will be a list of `{ pre, post, file }`
        '';
        default = "";
        type = descriptionsWithFiles;
      };
    };
    pkgs = lib.mkOption {
      type = lib.types.pkgs;
      description = ''
        The nixpkgs pkgs instance to use.

        Required in order to access `.wrapper` attribute,
        either directly, or indirectly.
      '';
    };
    package = lib.mkOption {
      apply =
        package:
        builtins.foldl' (
          acc: v:
          builtins.addErrorContext "config.overrides type error in ${acc} wrapper module!" (
            if v.type == null then
              builtins.addErrorContext "If `type` is `null`, then `data` must be a function!" (v.data acc)
            else
              builtins.addErrorContext "while calling: (${acc}).${v.type}:" (
                builtins.addErrorContext
                  "If `type` is a string, then `config.package` must have that field, and it must be a function!"
                  acc.${v.type}
                  v.data
              )
          )
        ) package (wlib.dag.unwrapSort "overrides" config.overrides);
      type = lib.types.addCheck wlib.types.stringable (
        v: if builtins.isString v then wlib.types.nonEmptyLine.check v else true
      );
      description = ''
        The base package to wrap.
        This means `config.builderFunction` will be responsible
        for inheriting all other files from this package
        (like man page, /share, ...)

        The `config.package` value given by this option already has all
        values from `config.overrides` applied to it.
      '';
    };
    overrides = lib.mkOption {
      type = wlib.types.seriesOf (
        wlib.types.specWith {
          specialArgs = { inherit wlib; };
          modules = [
            {
              options = {
                data = lib.mkOption {
                  type = lib.types.raw;
                  description = ''
                    If type is null, then this is the function to call on the package.

                    If type is a string, then this is the data to pass to the function corresponding with that attribute.
                  '';
                };
                type = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.either (lib.types.enum [
                      "override"
                      "overrideAttrs"
                    ]) lib.types.str
                  );
                  default = null;
                  description = ''
                    The attribute of `config.package` to pass the override argument to.
                    If `null`, then data receives and returns the package instead.

                    If `null`, data must be a function.
                    If a `string`, `config.package` must have the corresponding attribute, and it must be a function.
                  '';
                };
                name = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    The name for targeting from the before or after fields of other specs.

                    If `null` it cannot be targeted by other specs.
                  '';
                };
                before = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = ''
                    Items that this spec should be ordered before.
                  '';
                };
                after = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = ''
                    Items that this spec should be ordered after.
                  '';
                };
              };
            }
          ];
        }
      );
      default = [ ];
      description = ''
        the list of `.override` and `.overrideAttrs` to apply to `config.package`

        Accessing `config.package` will return the package with all overrides applied.

        Accepts a list of `{ data, type ? null, name ? null, before ? [], after ? [] }`

        If `type == null` then `data` must be a function. It will receive and return the package.

        If `type` is a string like `override` or `overrideAttrs`, it represents the attribute of `config.package` to pass the `data` field to.

        If a raw value is given, it will be used as the `data` field, and `type` will be `null`.

        ```nix
        config.package = pkgs.mpv;
        config.overrides = [
          { # If they don't have a name they cannot be targeted!
            type = "override";
            after = [ "MPV_SCRIPTS" ];
            data = (prev: {
              scripts = (prev.scripts or []) ++ [ pkgs.mpvScripts.visualizer ];
            });
          }
          {
            name = "MPV_SCRIPTS";
            type = "override";
            data = (prev: {
              scripts = (prev.scripts or []) ++ [ pkgs.mpvScripts.modernz ];
            });
          }
          # the default `type` is `null`
          (pkg: pkg.override (prev: {
            scripts = (prev.scripts or []) ++ [ pkgs.mpvScripts.autocrop ];
          }))
          {
            type = null;
            before = [ "MPV_SCRIPTS" ];
            data = (pkg: pkg.override (prev: {
              scripts = (prev.scripts or []) ++ config.scripts;
            }));
          }
          { # It was already after "MPV_SCRIPTS" so this will stay where it is
            type = "overrideAttrs";
            after = [ "MPV_SCRIPTS" ];
            data = prev: {
              name = prev.name + "-wrapped";
            };
          }
        ];
        ```

        The above will add `config.scripts`, then `modernz` then `visualizer` and finally `autocrop`

        Then it will add `-wrapped` to the end of `config.package`'s `name` attribute.

        The sort will not always put the value directly after the targeted value, it fulfils the requested `before` or `after` dependencies and no more.

        You can modify the specs!

        The type supports type merging, so you may redeclare it in order to add more options or change default values.

        ```nix
        { config, lib, wlib, pkgs, ... }:{
          options.overrides = lib.mkOption {
            type = wlib.types.seriesOf (wlib.types.spec ({ config, ... }: {
              options = {};
              config = {};
            }));
          };
        }
        ```
      '';
    };
    passthru = lib.mkOption {
      type = wlib.types.lazyAttrsRecursive;
      default = { };
      description = ''
        Additional attributes to add to the resulting derivation's passthru.
        This can be used to add additional metadata or functionality to the wrapped package.
        Anything added under the attribute name `configuration` will be ignored, as that value is used internally.

        This uses `wlib.types.lazyAttrsRecursive` to support lazy evaluation of the attributes,
        as is often desired of passthru values.

        This means that you cannot `config.passthru.somevalue = lib.mkIf condition "some value";`

        But as a result, you can `config.passthru.somevalue = "''${config.wrapper}/some/path";`

        To achieve an optional value, use `config.passthru = lib.optionalAttrs { somevalue = "some value"; };`
      '';
    };
    drv = lib.mkOption {
      default = { };
      type = wlib.types.attrsRecursive;
      description = ''
        Extra attributes to add to the resulting derivation.

        Cannot affect `passthru`, or `outputs`. For that,
        use `config.passthru`, or `config.outputs` instead.

        Also cannot override `buildCommand`.
        That is controlled by the `config.builderFunction`
        and `config.sourceStdenv` options.
      '';
    };
    binDir = lib.mkOption {
      type = lib.types.nullOr wlib.types.nonEmptyLine;
      default = "bin";
      description = ''
        the directory the wrapped result will be placed into, with the name indicated by the `binName` option

        i.e. `"''${placeholder outputName}/<THIS_VALUE>/''${binName}"`
      '';
    };
    binName = lib.mkOption {
      type = lib.types.str;
      default = builtins.unsafeDiscardStringContext (
        if config.package.meta.mainProgram or null != null then
          baseNameOf (
            builtins.addErrorContext ''
              `config.package`: ${config.package} is not a derivation with a main executable.
              You must specify `config.binName` manually.
            '' (lib.getExe config.package)
          )
        else if builtins.isString config.package || builtins.isPath config.package then
          baseNameOf (toString config.package)
        else
          config.package.pname or config.package.name or (throw "config.binName was not able to be detected!")
      );
      description = ''
        The name of the binary to be output to `config.wrapperPaths.placeholder`

        If not specified, the default name from the package will be used.
      '';
    };
    exePath = lib.mkOption {
      type = lib.types.nullOr wlib.types.nonEmptyLine;
      default = builtins.unsafeDiscardStringContext (
        if config.package.meta.mainProgram or null != null then
          lib.removePrefix "/" (
            lib.removePrefix "${config.package}" (
              builtins.addErrorContext ''
                `config.package`: ${config.package} is not a derivation with a main executable.
                You must specify `config.exePath` manually.
              '' (lib.getExe config.package)
            )
          )
        else if builtins.isString config.package || builtins.isPath config.package then
          lib.optionalString (config.binDir != null) "${config.binDir}/"
          + "${baseNameOf (toString config.package)}"
        else
          lib.optionalString (config.binDir != null) "${config.binDir}/"
          + "${config.package.pname or config.package.name
            or (throw "config.binName was not able to be detected! Please specify it manually!")
          }"
      );
      description = ''
        The relative path to the executable to wrap. i.e. `bin/exename`

        If not specified, the path gained from calling `lib.getExe` on `config.package` and subtracting the path to the package will be used.
      '';
    };
    wrapperPaths = {
      input = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "${config.package}" + lib.optionalString (config.exePath != null) "/${config.exePath}";
        description = "The path which is to be wrapped by the result of `buildCommand`";
      };
      placeholder = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "${placeholder config.outputName}${config.wrapperPaths.relPath}";
        description = "The path which the result of `buildCommand` is to output its result to.";
      };
      relPath = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default =
          config.wrapperPaths.relDir + lib.optionalString (config.binName or "" != "") "/${config.binName}";
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
    outputName = lib.mkOption {
      type = wlib.types.nonEmptyLine;
      default =
        config.package.outputName or (
          if builtins.length (config.package.outputs or [ ]) > 0 then
            builtins.head config.package.outputs
          else
            "out"
        );
      description = ''
        The derivation output the wrapped binary will be placed into.

        This will also set the default output of the derivation.

        This means, it will be first in `config.outputs`, and
        the final drv will contain an `outputName` attribute with this name.

        Unfortunately, `nix build` will still build `out` by default.
        If you use this, know why you are doing so.

        This is primarily for wrapping packages which already have a non-standard default output name.
      '';
    };
    outputs = lib.mkOption rec {
      type =
        let
          base = lib.types.addCheck (lib.types.listOf lib.types.str) (v: builtins.length v > 0);
        in
        base // { description = "non-empty " + base.description or "listOf str"; };
      default = if type.check (config.package.outputs or [ ]) then config.package.outputs else [ "out" ];
      apply = v: [ config.outputName ] ++ lib.remove config.outputName v;
      description = ''
        Override the list of nix outputs that get symlinked into the final package.

        Default is `config.package.outputs` or `[ "out" ]` if invalid.

        `config.outputName` will always be the first item of the resulting list in `config.outputs`

        It is added via the apply field of the option for you.
      '';
    };
    buildCommand = lib.mkOption {
      type = wlib.types.dagOf lib.types.lines;
      default = { };
      description = ''
        This option is to be used to fulfill the contract formed by `config.wrapperPaths`

        This option is used by builderFunction to create a build script which will be ran in the resulting derivation.

        The relative path to the thing to wrap is `config.wrapperPaths.input`

        The result should be created at `config.wrapperPaths.placeholder`

        In most wrapper modules, this contract has been fulfilled for you by `wlib.modules.makeWrapper`
        and `wlib.modules.symlinkScript`, which are imported by `wlib.modules.default`

        However, you may add extra entries, and place them before or after the commands provided by those modules.

        This is a more flexible form of providing derivation build commands than the normal `drv.buildPhase` style options.
        However, those are also usable, as are the other `drv` attributes such as things like `drv.__structuredAttrs`.
      '';
    };
    builderFunction = lib.mkOption {
      type = lib.types.functionTo (
        lib.types.either lib.types.str (lib.types.functionTo (lib.types.attrsOf lib.types.raw))
      );
      description = ''
        This is usually an option you will never have to redefine.

        This option takes a function receiving the following arguments:

        module arguments + `buildCommand` + `pkgs.callPackage`

        `buildCommand` is the already sorted and concatenated result of the `config.buildCommand` DAG option,
        for convenience.

        This function is in charge of running the generated `buildCommand` build script,
        generated from the `config.buildCommand` option.

        The function provided may be in 1 of 3 forms.

        - The function is to return a string which will be added to the buildCommand of the wrapper.

        ```
        {
          wlib,
          config,
          buildCommand,
          ... # <- anything you can get from pkgs.callPackage
        }@initialArgs:
        buildCommand # <- gets provided to buildCommand attribute of the final drv
        ```

        - Alternatively, it may return a function which returns a set like:

        ```nix
        { wlib, config, buildCommand, ... }@initialArgs:
        drvArgs:
        drvArgs // { inherit buildCommand; }
        ```

        If it does this, that function will be given the final computed derivation attributes,
        and it will be expected to return the final attribute set to be passed to `pkgs.stdenv.mkDerivation`.

        Regardless of if you return a string or function,
        `passthru.wrap`, `passthru.apply`, `passthru.eval`, `passthru.extendModules`, `passthru.override`,
        `passthru.overrideAttrs` will be added to the thing you return, and `config.sourceStdenv` will be handled for you.

        However:

        - You can also return a _functor_ with a (required) `mkDerivation` field.

        ```nix
          { config, stdenv, buildCommand, wlib, ... }@initialArgs:
          {
            inherit (stdenv) mkDerivation;
            __functor = {
              mkDerivation,
              __functor,
              defaultPhases, # [ "<all stdenv phases>" ... ]
              setupPhases, # phases: "if [ -z \"''${phases[*]:-}\" ]; then phases="etc..."; fi"
              runPhases, # "for curPhase in ''${phases[*]}; do runPhase \"$curPhase\"; done"
              ...
            }@self:
            defaultArgs:
            defaultArgs // {
              buildCommand =
                lib.optionalString config.sourceStdenv (setupPhases defaultPhases)
                + buildCommand
                + lib.optionalString config.sourceStdenv runPhases;
            };
          }
        ```

        - If you do this:
          - You are in control over the entire derivation.
          - This means you need to take care of `config.passthru` and `config.sourceStdenv` yourself.
          - The `mkDerivation` function will be called with the final result of your functor.

        As you can see, you are provided with some things to help you via the `self` argument to your functor.

        The generated `passthru` items mentioned above are given to you as part of what is shown as defaultArgs above

        And you are also given some helpers to help you run the phases if needed!

        Tip: A _functor_ is a set with a `{ __functor = self: args: ...; }` field.
        You can call it like a function and it gets passed itself as its first argument!
      '';
      default = { buildCommand, ... }: buildCommand;
    };
    sourceStdenv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run the enabled stdenv phases on the wrapper derivation.

        NOTE: often you may prefer to use things like `drv.doDist = true;`,
        or even `drv.phases = [ ... "buildPhase" etc ... ];` instead,
        to override this choice in a more fine-grained manner
      '';
    };
    wrapper = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = ''
        The final wrapped package.

        You may still call `.eval` and the rest on the package again afterwards.

        Accessing this value without defining `pkgs` option,
        either directly, or via some other means like `.wrap`,
        will cause an error.
      '';
      default =
        let
          inherit (config)
            pkgs
            package
            binName
            ;
          meta =
            (package.meta or { })
            // {
              ${if config.binDir == "bin" && binName != "" then "mainProgram" else null} = binName;
            }
            // (config.drv.meta or { });
          version =
            package.version or meta.version or package.revision or meta.revision or package.rev or meta.rev
              or package.release or meta.release or package.releaseDate or meta.releaseDate or "master";
          defaultargs = {
            passthru = config.passthru // {
              configuration = config;
              inherit (config)
                wrap
                eval
                apply
                extendModules
                ;
              override =
                overrideArgs:
                config.wrap {
                  _file = wlib.core;
                  overrides = lib.mkOverride (options.overrides.highestPrio or lib.modules.defaultOverridePriority) [
                    {
                      type = "override";
                      data = overrideArgs;
                    }
                  ];
                };
              overrideAttrs =
                overrideArgs:
                config.wrap {
                  _file = wlib.core;
                  overrides = lib.mkOverride (options.overrides.highestPrio or lib.modules.defaultOverridePriority) [
                    {
                      type = "overrideAttrs";
                      data = overrideArgs;
                    }
                  ];
                };
            };
            dontUnpack = true;
            dontConfigure = true;
            dontPatch = true;
            dontFixup = true;
            preferLocalBuild = true;
            name = package.name or "${package.pname or binName}-${version}";
            ${
              if builtins.isString (package.pname or binName) && package.pname or binName != "" then
                "pname"
              else
                null
            } =
              package.pname or binName;
            inherit version meta;
            inherit (config) outputs;
            outputName = config.outputName or "out";
            buildPhase = ''
              runHook preBuild
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              runHook postInstall
            '';
          }
          // removeAttrs config.drv [
            "passthru"
            "buildCommand"
            "outputs"
            "meta"
          ];
          errormsg = "config.builderFunction function must return (a string) or (a function that receives attrset and returns an attrset) or (a functor as described in https://nix-community.github.io/nix-wrapper-modules/core.html#builderfunction)";
          defaultPhases = [
            "unpackPhase"
            "patchPhase"
            "configurePhase"
            "buildPhase"
            "checkPhase"
            "installPhase"
            "fixupPhase"
            "installCheckPhase"
            "distPhase"
          ];
          setupPhases =
            phases:
            let
              capitalize =
                s:
                let
                  first = builtins.substring 0 1 s;
                  rest = builtins.substring 1 (builtins.stringLength s - 1) s;
                in
                lib.strings.toUpper first + rest;
            in
            if builtins.isList phases then
              (lib.pipe phases [
                (builtins.concatMap (n: [
                  "\${pre${capitalize n}s[*]:-}"
                  "${n}"
                ]))
                (v: if builtins.length v > 0 then builtins.tail v else [ ])
                (v: [ "\${prePhases[*]:-}" ] ++ v ++ [ "\${postPhases[*]:-}" ])
                (builtins.concatStringsSep " ")
                wlib.escapeShellArgWithEnv
                (v: "\n" + ''if [ -z "''${phases[*]:-}" ]; then phases=${v}; fi'' + "\n")
              ])
            else
              ''

                if [ -z "''${phases[*]:-}" ]; then
                    phases="''${prePhases[*]:-} unpackPhase patchPhase ''${preConfigurePhases[*]:-} \
                        configurePhase ''${preBuildPhases[*]:-} buildPhase checkPhase \
                        ''${preInstallPhases[*]:-} installPhase ''${preFixupPhases[*]:-} fixupPhase installCheckPhase \
                        ''${preDistPhases[*]:-} distPhase ''${postPhases[*]:-}";
                fi
              '';
          runPhases = ''

            for curPhase in ''${phases[*]}; do
                runPhase "$curPhase"
            done
          '';
          initial = pkgs.callPackage config.builderFunction (
            args
            // {
              buildCommand = lib.pipe config.buildCommand [
                (wlib.dag.unwrapSort "buildCommand")
                (map (v: v.data))
                (builtins.concatStringsSep "\n")
              ];
            }
          );
        in
        (initial.mkDerivation or pkgs.stdenv.mkDerivation) (
          if lib.isFunction initial then
            lib.pipe initial [
              (
                v:
                if v ? mkDerivation then
                  v
                  // {
                    inherit runPhases setupPhases defaultPhases;
                    configuration = config;
                  }
                else
                  v
              )
              (f: f defaultargs)
              (
                v:
                if initial ? mkDerivation then
                  v
                else if builtins.isAttrs v then
                  v
                  // {
                    passthru = v.passthru or { } // defaultargs.passthru;
                    passAsFile = [ "buildCommand" ] ++ v.passAsFile or [ ];
                    buildCommand =
                      lib.optionalString config.sourceStdenv (setupPhases defaultPhases)
                      + v.buildCommand or ""
                      + lib.optionalString config.sourceStdenv runPhases;
                  }
                else
                  throw errormsg
              )
            ]
          else if builtins.isString initial then
            defaultargs
            // {
              passAsFile = [ "buildCommand" ] ++ defaultargs.passAsFile or [ ];
              buildCommand =
                lib.optionalString config.sourceStdenv (setupPhases defaultPhases)
                + initial
                + lib.optionalString config.sourceStdenv runPhases;
            }
          else
            throw errormsg
        );
    };
    wrap = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      readOnly = true;
      description = ''
        Function to extend the current configuration with additional modules.
        Can accept a single module, or a list of modules.
        Re-evaluates the configuration with the original settings plus the new module(s).

        Returns the updated package.
      '';
      default = module: (config.eval module).config.wrapper;
    };
    apply = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      description = ''
        Function to extend the current configuration with additional modules.
        Can accept a single module, or a list of modules.
        Re-evaluates the configuration with the original settings plus the new module(s).

        Returns `.config` from the `lib.evalModules` result
      '';
      default = module: (config.eval module).config;
    };
    eval = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      description = ''
        Function to extend the current configuration with additional modules.
        Can accept a single module, or a list of modules.
        Re-evaluates the configuration with the original settings plus the new module(s).

        Returns the raw `lib.evalModules` result
      '';
      default = module: extendModules { modules = lib.toList module; };
    };
    extendModules = lib.mkOption {
      type = lib.types.raw // {
        inherit (lib.types.functionTo lib.types.raw) description;
      };
      readOnly = true;
      default = args // {
        __functionArgs = lib.functionArgs extendModules;
        __functor = _: extendModules;
      };
      description = ''
        Alias for `.extendModules` so that you can call it from outside of `wlib.types.subWrapperModule` types

        In addition, it is also a set which stores the function args for the module evaluation.
        This may prove useful when dealing with subWrapperModules or packages, which otherwise would not have access to some of them.
      '';
    };
  };
}
