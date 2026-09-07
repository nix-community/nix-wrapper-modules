{
  lib,
  wlib,
  wrapperModules,
  modules,
  checks,
  modulesPath,
  maintainers,
}:
let
  inherit (lib) toList;
in
{
  inherit
    wrapperModules
    modules
    checks
    maintainers
    modulesPath
    ;

  types = import ./types.nix { inherit lib wlib; };

  dag = import ./dag.nix { inherit lib wlib; };

  makeWrapper = import ./makeWrapper { inherit lib wlib; };

  core = toString ./core.nix;

  /**
    calls `nixpkgs.lib.evalModules` with the core module imported and `wlib` added to `specialArgs`

    `wlib.evalModules` takes the same arguments as `nixpkgs.lib.evalModules`
  */
  evalModules =
    evalArgs:
    lib.evalModules (
      evalArgs
      // {
        modules = [
          wlib.core
        ]
        ++ (evalArgs.modules or [ ]);
        specialArgs = (evalArgs.specialArgs or { }) // {
          inherit (wlib) modulesPath;
          inherit wlib;
        };
      }
    );

  /**
    `evalModule = module: wlib.evalModules { modules = lib.toList module; };`

    Evaluates the module along with the core options, using `lib.evalModules`

    Takes a module (or list of modules) as its argument.
    Returns the result from `lib.evalModules` directly.

    To submit a module to this repo, this function must be able to evaluate it.

    The wrapper module system integrates with NixOS module evaluation:
    - Uses `lib.evalModules` for configuration evaluation
    - Supports all standard module features (imports, conditionals, mkIf, etc.)
    - Provides `config` for accessing evaluated configuration
    - Provides `options` for introspection and documentation
  */
  evalModule = module: wlib.evalModules { modules = toList module; };

  /**
    ```nix
    evalPackage = module: (wlib.evalModules { modules = lib.toList module; }).config.wrapper;
    ```

    Evaluates the module along with the core options, using `lib.evalModules`

    Takes a module (or list of modules) as its argument.

    Returns the final wrapped package from `eval_result.config.wrapper` directly.

    Requires a `pkgs` to be set.

    ```nix
    home.packages = [
      (wlib.evalPackage [
        { inherit pkgs; }
        ({ pkgs, wlib, lib, ... }: {
          imports = [ wlib.modules.default ];
          package = pkgs.hello;
          flags."--greeting" = "greetings!";
        })
      ])
      (wlib.evalPackage [
        { inherit pkgs; }
        ({ pkgs, wlib, lib, ... }: {
          imports = [ wlib.wrapperModules.tmux ];
          plugins = [ pkgs.tmuxPlugins.onedark-theme ];
        })
      ])
    ];
    ```
  */
  evalPackage = module: (wlib.evalModules { modules = toList module; }).config.wrapper;

  /**
    Produces a module for another module system,
    that can be imported to configure and/or install a wrapper module.

    *Arguments:*

    ```nix
    {
      name, # string
      value, # wrapper module or list of wrapper modules
      ... # other evalModules arguments if necessary
    }:
    ```

    It will return the value of `config.install`, which may be imported as a module in other module systems.

    If you did not set `config.install.optionLocation`, it will default to making the option at `config.wrappers.${name}`

    The exported module may contain specific integrations for the module classes
    indicated by the provided attributes in `config.install.modules` for that wrapper module.

    If used in a module class not specified in that set, it will only create the submodule option containing the wrapper module.

    Likewise, if used in another wrapper module, that is all it will do as well.

    If you have your wrapper module imported via an `attrsOf subWrapperModule` option in an evaluation external to the target module system,
    as is the case when using the `flake-parts` module, you DO NOT NEED THIS FUNCTION.

    This is because `config.install.optionLocation` will default to `[ "wrappers" (lib.last _prefix) ]` if present.

    In that case, you should do something like `flake.nixosModules.<name> = { imports = [ config.flake.wrappers.<name>.install ]; };` directly.

    Again, if you are using the `flake-parts` module, or importing it in a similar manner, YOU DO NOT NEED THIS FUNCTION.

    *Examples:*

    ```nix
    # in a nixos module
    { ... }: {
      imports = [
        (getInstallModule { name = "?"; value = someWrapperModule; })
      ];
      config.wrappers."?" = {
        enable = true;
        env.EXTRAVAR = "TEST VALUE";
      };
    }
    ```

    ```nix
    # in a home-manager module
    { ... }: {
      imports = [
        (getInstallModule { name = "?"; value = someWrapperModule; })
      ];
      config.wrappers."?" = {
        enable = true;
        env.EXTRAVAR = "TEST VALUE";
      };
    }
    ```

    If needed, you can also grab the package directly with `config.wrappers."?".wrapper`

    It will try to provide a `pkgs` to the `subWrapperModule` automatically.

    If the target module evaluation does not provide a `pkgs` via its module arguments to use,
    you will need to supply it to the submodule yourself later.

    Again, if you are using the `nix-wrapper-modules` `flake-parts` module, you should do something like this instead:

    ```nix
    { config, ... }: {
      flake.wrappers.someWrapperModule = a_wrapper_module;
      flake.modules.nixos.someNixosModule = config.flake.wrappers.someWrapperModule.install;
      flake.modules.homeManager.someHomeModule = config.flake.wrappers.someWrapperModule.install;
      # the above requires these flake-parts modules be imported somewhere
      imports = [ inputs.flake-parts.flakeModules.modules inputs.nix-wrapper-modules.flakeModules.wrappers ];
    };
    ```
  */
  getInstallModule =
    { name, value, ... }@evalModulesArgs:
    (wlib.evalModules (
      removeAttrs evalModulesArgs [
        "name"
        "value"
      ]
      // {
        modules = toList value;
        prefix = [ name ];
      }
    )).config.install;

  /**
    Imports `wlib.modules.default` then evaluates the module. It then returns `.config` so that `.wrap` is easily accessible!

    Use this when you want to quickly create a wrapper but without providing it a `pkgs` yet.

    Equivalent to:

    ```nix
    wrapModule = (wlib.evalModule wlib.modules.default).config.apply;
    ```

    Example usage:

    ```nix
      helloWrapper = wrapModule ({ config, wlib, pkgs, ... }: {
        options.greeting = lib.mkOption {
          type = lib.types.str;
          default = "hello";
        };
        config.package = pkgs.hello;
        config.flags = {
          "--greeting" = config.greeting;
        };
      };

      # This will return a derivation that wraps the hello package with the --greeting flag set to "hi".
      helloWrapper.wrap {
        pkgs = pkgs;
        greeting = "hi";
      };
      ```
  */
  wrapModule =
    module: (wlib.evalModules { modules = [ wlib.modules.default ] ++ (toList module); }).config;

  /**
    Imports `wlib.modules.default` then evaluates the module. It then returns the wrapped package.

    Use this when you want to quickly create a wrapped package directly, which does not have an existing module already.

    Requires a `pkgs` to be set.

    Equivalent to:

    ```nix
    wrapPackage = module: wlib.evalPackage ([ wlib.modules.default ] ++ toList module);
    ```
  */
  wrapPackage = module: wlib.evalPackage ([ wlib.modules.default ] ++ toList module);

  /**
    mkOutOfStoreSymlink :: pkgs -> path -> { out = ...; ... }

    Lifted straight from home manager, but requires pkgs to be passed to it first.

    Creates a symlink to a local absolute path, does not check if it is a store path first.

    Returns a store path that can be used for things which require a store path.
  */
  mkOutOfStoreSymlink =
    pkgs: path:
    let
      pathStr = toString path;
      name = baseNameOf pathStr;
    in
    pkgs.runCommandLocal name { } "ln -s ${lib.escapeShellArg pathStr} $out";

  /**
    getPackageOutputsSet ::
      Derivation -> AttrSet

    Given a package derivation, returns an attribute set mapping each of its
    output names (e.g. "out", "dev", "doc") to the corresponding output path.

    This is useful when a wrapper or module needs to reference multiple outputs
    of a single derivation. If the derivation does not define multiple outputs,
    an empty set is returned.

    Example:
      getPackageOutputsSet pkgs.git
      => {
        out = /nix/store/...-git;
        man = /nix/store/...-git-man;
      }
  */
  getPackageOutputsSet =
    package:
    if package ? outputs then
      lib.listToAttrs (
        map (output: {
          name = output;
          value = if package ? ${output} then package.${output} else null;
        }) package.outputs
      )
    else
      { };

  /**
    Escape a shell argument while preserving environment variable expansion.

    This escapes backslashes and double quotes to prevent injection, then

    wraps the result in double quotes.

    Unlike lib.escapeShellArg which uses single quotes, this allows

    environment variable expansion (e.g., `$HOME`, `${VAR}`).

    Caution! This is best used by the `nix` backend for `wlib.modules.makeWrapper` to escape things,
    because the `shell` and `binary` implementations pass their args to `pkgs.makeWrapper` at **build** time,
    so allowing variable expansion may not always do what you expect!

    - Example:

    ```nix

    escapeShellArgWithEnv "$HOME/config.txt"

    => "\"$HOME/config.txt\""

    escapeShellArgWithEnv "/path/with\"quote"

    => "\"/path/with\\\"quote\""

    escapeShellArgWithEnv "/path/with\\backslash"

    => "\"/path/with\\\\backslash\""

    ```
  */
  escapeShellArgWithEnv = arg: ''"${lib.escape [ ''\'' ''"'' ] (toString arg)}"'';

  /**
    Wrap a function (or callable attribute set) to make it customizable via a
    named override entry.

    A slightly generalized version of `nixpkgs.lib.makeOverridable`, with explicit
    support for:
    - custom override names
    - configurable argument-merging semantics
    - preserving override entry points across common derivation-like patch
      functions (e.g. `override`, `overrideAttrs`, `overrideDerivation`)

    This helper turns `f` into a functor that:
    - Preserves the original argument signature of `f`
    - Exposes an override function under the attribute `${name}`
    - Recomputes `f` when arguments are overridden
    - Re-attaches `${name}` to selected callable attributes on the result of `f`,
      so that chaining through derivation-style patch functions does not lose
      the custom override entry

    Signature:

    ```nix
    makeCustomizable =
      name:
      {
        patches ? [
          "override"
          "overrideAttrs"
          "overrideDerivation"
        ],
        mergeArgs ?
          origArgs: newArgs:
            origArgs // (if lib.isFunction newArgs then newArgs origArgs else newArgs),
      }@opts:
      f:
    ```

    Parameters:
    - `name`:
        The attribute name under which the override function is exposed
        (e.g. `customize`, `withPackages`). This attribute is attached both to `f`
        itself and to applicable results returned by calling `f`.

    - `opts.patches`:
        A list of attribute names on the *result* of `f` that should propagate
        the named override. Each listed attribute is expected to be callable
        when present. This is primarily intended for derivation-like results,
        ensuring that calling methods such as `override`, `overrideAttrs`,
        or `overrideDerivation` preserves the custom override entry rather than
        discarding it. It will only patch the value if present.

    - `opts.mergeArgs`:
        A function controlling how new arguments are merged with the original
        arguments when overriding. It receives `origArgs` and `newArgs` and
        must return the argument used to re-invoke `f`. By default, this
        performs a shallow merge, evaluating `newArgs` if it is a function.

    - `f`:
        The function (or callable attribute set) to wrap. If `f` is an attribute
        set, its additional attributes are preserved, and an existing `${name}`
        entry (if present) is composed rather than replaced.

    Semantics:
    - Argument overrides recompute `f` with merged arguments.
    - Result-level patches recompute `f` and then delegate to the corresponding
      callable attribute on the result.
    - Returned attribute sets and functions gain a `${name}` attribute that can
      be chained arbitrarily.

    Example:

    ```nix
      luaEnv = wlib.makeCustomizable
        "withPackages"
        { mergeArgs = og: new: lp: og lp ++ new lp; }
        pkgs.luajit.withPackages
        (lp: [ lp.inspect ]);

      # inspect + cjson
      luaEnv2 = luaEnv.withPackages (lp: [ lp.cjson ]);
      # inspect + cjson + luassert
      luaEnv3 = luaEnv2.withPackages (lp: [ lp.luassert ]);
    ```
  */
  makeCustomizable =
    # https://github.com/NixOS/nixpkgs/blob/f36330bf81e58a7df04a603806c9d01eefc7a4bb/lib/customisation.nix#L154
    name:
    {
      patches ? [
        "override"
        "overrideAttrs"
        "overrideDerivation"
      ],
      mergeArgs ?
        origArgs: newArgs: origArgs // (if lib.isFunction newArgs then newArgs origArgs else newArgs),
    }@opts:
    f:
    let
      mkOver = wlib.makeCustomizable name opts;
      # Creates a functor with the same arguments as f
      mirrorArgs = lib.mirrorFunctionArgs f;
      # Recover overrider and additional attributes for f
      # When f is a callable attribute set,
      # it may contain its own `f.${name}` and additional attributes.
      # This helper function recovers those attributes and decorate the overrider.
      recoverMetadata =
        if builtins.isAttrs f then
          fDecorated:
          # Preserve additional attributes for f
          f
          // fDecorated
          # Decorate f.${name} if presented
          // {
            ${if builtins.isString name && f ? "${name}" then name else null} = fdrv: mkOver (f.${name} fdrv);
          }
        else
          (x: x);
      decorate = f': recoverMetadata (mirrorArgs f');
    in
    decorate (
      origArgs:
      let
        result = f origArgs;
        # Re-call the function but with different arguments
        overrideArgs = mirrorArgs (newArgs: mkOver f (mergeArgs origArgs newArgs));
        # Change the result of the function call by applying g to it
        overrideResult = g: mkOver (mirrorArgs (args: g (f args))) origArgs;
      in
      if builtins.isAttrs result then
        result
        // lib.pipe patches [
          (map (patch: {
            ${if result ? "${patch}" then patch else null} = fdrv: overrideResult (x: x.${patch} fdrv);
          }))
          (builtins.foldl' (acc: v: acc // v) { })
        ]
        // {
          ${name} = overrideArgs;
        }
      else if builtins.isFunction result then
        # Transform the result into a functor while propagating its arguments
        lib.setFunctionArgs result (lib.functionArgs result)
        // {
          ${name} = overrideArgs;
        }
      else
        result
    );

  /**
    Map over the values of an attribute set, yielding a list with index.

    ```nix
    mapAttrsToList0 ::
      (int -> string -> a -> b) -> AttrSet -> List b
    ```

    Converts an attribute set to a list by applying `f` to each name/value pair
    along with its 0-based index. Equivalent to `lib.mapAttrsToList` but includes
    the index as the first argument.

    Parameters:
    - `f`: A function receiving `(index, name, value)` for each attribute
    - `v`: The attribute set to iterate over

    Example:
    ```nix
    mapAttrsToList0 (i: name: value: "${toString i}-${name}-${value}") { a = "x"; b = "y"; }
    => [ "0-a-x" "1-b-y" ]
    ```
  */
  mapAttrsToList0 =
    f: v: lib.imap0 (i: v: f i v.name v.value) (lib.mapAttrsToList lib.nameValuePair v);

  /**
    Partition an attribute set into two attribute sets based on a predicate.

    The predicate is applied to each attribute as `(name: value: ...)`. Attributes
    for which the predicate returns `true` are placed in `right`, and all others
    are placed in `wrong`.

    This is like `lib.lists.partition`, but for attribute sets.

    Type:
    ```
      (string -> any -> bool) -> attrs -> {
        right :: attrs;
        wrong :: attrs;
      }
    ```

    Example:
    ```nix
      partitionAttrs (name: value: value > 10) {
        a = 5;
        b = 20;
        c = 15;
      }
      => {
        right = { b = 20; c = 15; };
        wrong = { a = 5; };
      }
    ```

    Notes:
    - Iteration order follows `builtins.attrNames`, which is lexicographically sorted.
  */
  partitionAttrs =
    pred: attrs:
    builtins.foldl'
      (
        acc: name:
        let
          value = attrs.${name};
        in
        if pred name value then
          acc
          // {
            right = acc.right // {
              ${name} = value;
            };
          }
        else
          acc
          // {
            wrong = acc.wrong // {
              ${name} = value;
            };
          }
      )
      {
        right = { };
        wrong = { };
      }
      (builtins.attrNames attrs);

  /**
    `genStr` :: `string` -> `int` -> `string`

    or

    `genStr` :: (`int`: `string`) -> `int` -> `string`

    Generates a string by repeating the input string the specified number of times,
    or by calling the provided function with the index the specified number of times.
  */
  genStr = str: num: builtins.concatStringsSep "" (builtins.genList (lib.toFunction str) num);

  /**
    `repeatStr` :: `string` -> `int` -> `string`

    Generates a string by repeating the input string the specified number of times
  */
  repeatStr = str: num: builtins.concatStringsSep "" (builtins.genList (_: str) num);

  /**
    Converts a Nix value to a KDL document string.

    The top-level argument, and individual nodes can be either an attrset or a list of attrsets:
    - Attrset: each pair becomes a node (in a child block if not the top level)
    - List of attrsets: each attrset of nodes is processed, and then they are concatenated in sequence.
      This is useful for when there are repeated node names

    Inside nodes, attrsets and lists of attrsets create child blocks.

    For any individual node, instead of providing the content as an attrset or an attrset of lists,
    you may instead provide a function.

    Functions produce nodes with:
    - `props`: (optional) node arguments. May be an attrset, or a list containing mixed values and attrsets.
      Plain values are provided as arguments. Attrset values are mapped to properties, i.e. `nodename "key"="value" {}`.
      These values may not be sensibly nested further.
    - `content`: (optional) child block content (attrs or list of attrs, like top level)
    - `type`: (optional) a string to be placed in a type annotation on the node name. (If you provide a function returning a set with this field to props, it will add it to the value instead)
    - `custom`: (optional) a function of type `{ indent, lvl, name } -> string` which is to replace the node (including its name) with a custom string.

    This means you can make a node with only a name like `toKdl { mynode = _: { }; }`, which will produce a string containing just `mynode`

    If you provide a list which contains more than just attrsets as a node's value, it will be assumed to be arguments/properties instead.

    If you provide a primitive value, it will likewise be considered to be an argument.

    Otherwise, it will be assumed to be a block, and to pass arguments, you should use the function form.

    The argument to the function is provided by calling the function with `lib.fix`.

    The top level argument to `wlib.toKdl` may also be a function, but it is slightly different
    than the function form you can provide to a normal node.

    As a top-level argument, rather than passing the content directly as the argument,
    you may provide a function like:

    ```nix
    _: {
      lvl = 0;
      indent = "  ";
      version = 2; # or 1 (default 2)
      content = set_or_list_of_sets; # required
    }
    # This allows you to set the indentation level of the generated nodes, and indentation width/character.
    ```

    Example:

    ```nix
    {
      # plain node (no args, no block)
      a = _: { };
      # primitive → argument
      b = 1;
      # list of primitives → multiple args
      c = [ "x" 2 true null ];
      # attrset → child block
      d = {
        x = 1;
      };
      # list of attrsets → repeated child nodes
      e = [
        { x = 1; }
        { x = 2; }
      ];
      # function form: props (args + properties) + content (block)
      f = _: {
        props = [
          "arg1"
          { key = "val"; }
        ];
        content = {
          g = _: { };
        };
      };
      # function with only props (no block)
      h = _: {
        props = { k = "v"; };
      };
      # function with only content (block, no props)
      i = _: {
        content = {
          j = 1;
        };
      };
      # nested combination
      k = {
        l = [
          { m = "a"; }
          { m = "b"; }
        ];
      };
      # typed argument in props (list form)
      n = [ (_: { type = "string"; content = "o"; }) ];
      # typed argument and typed property and block content
      p = _: {
        props = [ (_: { type = "string"; content = "q"; }) { r = (_: { type = "string"; content = "s"; }); } ];
        type = "string";
        content = {
          t = "u";
        };
      };
    }
    ```

    ```kdl
      "a"
      "b" 1
      "c" "x" 2 true #null
      "d"  {
        "x" 1
      }
      "e"  {
        "x" 1
        "x" 2
      }
      "f" "arg1" "key"="val" {
        "g"
      }
      "h" "k"="v"
      "i"  {
        "j" 1
      }
      "k"  {
        "l"  {
          "m" "a"
          "m" "b"
        }
      }
      "n" (string)"o"
      (string)"p" (string)"q" "r"=(string)"s" {
        "t" "u"
      }
    ```
  */
  toKdl = import ./toKdl.nix { inherit lib wlib; };

  /**
    Sanitize a string into a valid environment variable name.

    This function sanitizes all characters that are not allowed in typical
    POSIX environment variable names (`[A-Za-z0-9_]`), and ensures the
    resulting string starts with a valid leading character (`[A-Za-z_]`).

    Behavior:
    - All invalid characters are replaced with underscore characters (`_`)

    Examples:
    ```
      sanitizeEnvVarName "FOO-BAR"     => "FOO_BAR"
      sanitizeEnvVarName "123.abc"      => "_23_abc"
      sanitizeEnvVarName "!@#"         => "___"
      sanitizeEnvVarName "hello, world!" => "hello__world_"
    ```

    Notes:
    - Only ASCII characters are considered; all other characters are removed
    - This does not guarantee uniqueness across multiple inputs
  */
  sanitizeEnvVarName =
    s:
    let
      isUpper = c: c >= "A" && c <= "Z";
      isLower = c: c >= "a" && c <= "z";
      isDigit = c: c >= "0" && c <= "9";

      valid =
        i: c:
        if i == 0 then
          isUpper c || isLower c || c == "_"
        else
          isUpper c || isLower c || isDigit c || c == "_";
    in
    lib.concatStrings (lib.imap0 (i: c: if valid i c then c else "_") (lib.stringToCharacters s));

  /**
    Placeholder value used when overriding a non-main field of a spec type.

    When overriding the main field of a spec type, things work as you might expect.

    ```nix
    # assuming these were already set in another module:

    config.env.SOME_ALIAS.data = lib.mkForce "SOME OTHER VALUE";

    config.env.ANOTHER_ALIAS = {
      data = lib.mkForce "SOME OTHER VALUE";
      after = [ "SOME_ALIAS" ];
    };
    ```

    However, overriding ONLY an auxiliary field is slightly more challenging.

    Each value provided to a spec type MUST be valid, or it is converted.

    But without the main field defined, it is not a valid spec.

    To prevent this, we must explicitly ignore the main field.

    Example (overriding a non-main field):
    ```nix
    config.env.SOME_ALIAS = {
      after = [ "OTHER_ALIAS" ];
      data = wlib.ignoreSpecField;
    };
    ```

    However, for the case of the `env` option, it accepts function submodules.

    If the spec type has `dontConvertFunctions = true`, like `env` does,
    then you can do this instead.

    ```nix
    config.env.SOME_ALIAS = { ... }: { after = [ "OTHER_ALIAS" ]; };
    ```
  */
  ignoreSpecField = lib.mkIf false null;

}
