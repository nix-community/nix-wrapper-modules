{ lib, wlib }: {
  /**
    Produces markdown documentation for an evaluated wrapper module.

    These functions are specific to wrapper modules and will not work on other modules.

    While the normal nixos `pkgs.nixosOptionsDoc` functions can be used for wrapper modules,
    the result is less than ideal.

    This is because wrapper modules are all made up of the same base set of options,
    which often outnumber the options that are actually offered for that specific program.

    This function analyzes the import graph of the module evaluation to group
    wrapper module options by the closest parent module containing a `meta.description` or `meta.maintainers` entry.

    This makes it much easier when generating documentation to show the relevant options first on the page for that wrapper module,
    so that people do not need to scroll through the base wrapper options to find the options they want interspersed within.

    ```nix
    {
      options,
      includeCore ? true,
      transform ? null,
      prefix ? false,
      warningsAreErrors ? false,
      nameFromModule ? { file, ... }: ...,
      moduleStartsOpen ? i: mod: i == 1,
      descriptionStartsOpen ? type: i: mod: i == 1,
      descriptionIncluded ? type: i: mod: true,
      extraModuleNotes ? i: { maintainers, ... }@mod: ...,
      declaredBy ? { declarations, ... }@opt: ...,
    }:
    ```

    Normalization options:

    - `options`: The evaluated options set from a wrapper module.
    - `includeCore`: Whether to include the core module in the output. Defaults
      to `true`.
    - `transform`: A function applied to each option, returning a list of
      options. Defaults to omitting `_module` options.
    - `prefix`: Passed to `options.extendModules` when it is `null` or a list.
      Defaults to `false`. `[ "flake" "wrappers" ]` is a good value for those making use of the flake parts module

    Markdown rendering options:

    - `warningsAreErrors`: When `true`, throw if a visible option has no
      description. When `false`, use `lib.warn` instead so all missing
      descriptions can be seen. Defaults to `true`.
    - `nameFromModule`: A function receiving a representation of a module and returning its display
      name. Defaults to removing the `wlib.modulesPath` prefix and the
      `/module.nix` suffix from the module's `file`.
    - `moduleStartsOpen`: A function `i: mod: bool` controlling whether a
      module's `<details>` section starts open, where `i` is its 1-based index.
      Defaults to `i == 1`, opening only the first module.
    - `descriptionStartsOpen`: A function `type: i: mod: bool` controlling
      whether a module description's `<details>` section starts open, where
      `type` is `"pre"` for the overview or `"post"` for the notes. Defaults to
      `i == 1`, opening only the first description.
    - `descriptionIncluded`: A function `type: i: mod: bool` controlling whether
      a module description is included, with the same `type` values as
      `descriptionStartsOpen`. Defaults to always `true`.
    - `extraModuleNotes`: A function `i: mod: string` returning extra markdown
      notes to place before a module's descriptions. Defaults to listing the
      module's maintainers for the first module, when there are any.
    - `declaredBy`: A function receiving an option and returning a markdown
      string listing its declarations. Defaults to linking declarations under
      `wlib.modulesPath` to their source on GitHub.

    The documentation is rendered into markdown with collapsible `<details>`
    sections for each module, and typed text values are rendered as fenced
    `nix` code blocks when they are literal expressions.

    Returns a markdown string with its string context discarded.

    Example usage (with the trigger line for `wlib.docs.wrapperModuleMdBookStyle` mdbook extension module included):

    ```nix
    markdownString = ''
      <div nix-wrapper-module-documentation-style-tag hidden></div>

      # MY WRAPPER MODULE's NAME HERE

    '' + wlib.docs.wrapperModuleMD {
      inherit (wlib.evalModule [
        ./path-to-your-module.nix
        {
          _module.check = false;
          inherit pkgs;
        }
      ]) options;
    };
    ```
  */
  wrapperModuleMD = import ./rendermd.nix {
    inherit
      wlib
      lib
      ;
    inherit (wlib.docs) normWrapperDocs fixupDocValues;
  };

  /**
    Path to a wrapper module that improves the appearance of generated wrapper module documentation in mdbook.

    Import this module into an [mdbook wrapper module evaluation](https://nix-community.github.io/nix-wrapper-modules/wrapperModules/mdbook.html), then set
    `config.books.<your_book_name>.applyWrapperModuleStyles = true;`
    for each book that should use the added styles.

    The module adds an `applyWrapperModuleStyles` boolean option to every entry
    in `config.books`, and adds a javascript file to any book where it is enabled.

    The javascript adds dropdown arrows to the sidebar, which allow subchapters
    to be expanded and collapsed.

    In addition, for every markdown page given to mdbook containing the following line:

    `<div nix-wrapper-module-documentation-style-tag hidden></div>`

    it provides further CSS styling for indentation and details expansion
    elements, and syncs the expansion of elements on the page to the sidebar.

    GitHub already renders the dropdown arrows for the summary headings in line
    with the headings, so this CSS is unnecessary if viewing the generated
    markdown directly there.
  */
  wrapperModuleMdBookStyle = ./wrapper-module-mdbook-style.nix;

  /**
    Normalizes the options from an evaluated wrapper module into a list of modules suitable for documentation.

    These functions are specific to wrapper modules and will not work on other modules.

    This option returns the raw nix version of the aggregated information.

    Takes the arguments:

    ```nix
    {
      options,
      prefix ? false,
      transform ? null,
      includeCore ? true,
    }:
    ```

    - `options`: The evaluated options set from a wrapper module. It must provide
      `extendModules`, otherwise an error is thrown.
    - `prefix`: Passed to `options.extendModules` when it is `null` or a list,
      causing the options to be evaluated under that prefix.
    - `transform`: A function applied to each option after
      `lib.optionAttrSetToDocList`, returning a list of options. Returning `[ ]`
      omits the option, and returning multiple options duplicates it. Defaults to
      omitting `_module` options.
    - `includeCore`: Whether to include the module at `wlib.core` in the result.
      The core module is filtered out unless this is `true`.

    Each returned module contains its `file`, any available `description` and
    `maintainers` metadata, and `visible`, `hidden`, and `internal` option lists,
    with each option associated with the module that declares it.

    Options marked `internal` or `visible = false` are excluded from the visible
    list, and options are grouped by their `declarations` entry, falling back to
    `"<unknown-file>"` when a declaration is missing.
  */
  normWrapperDocs = import ./normopts.nix { inherit wlib lib; };

  /**
    Recursively converts documentation values into values that are safe to render or serialize.

    Takes an optional `processTypedText` function as its first argument, and the
    value to fix up as its second:

    ```nix
    fixupDocValues { processTypedText ? v: v; } value
    ```

    - `processTypedText`: A function that receives any set containing both
      `_type` and `text` (such as `literalExpression` and `literalMD` values)
      and returns its replacement. If it is not a function, an error is thrown.
      Defaults to returning the typed text set unchanged.

    Behavior by value type:
    - A set containing `_type` and `text` is passed to `processTypedText`.
    - A string-like value that is not a string (such as a path or derivation)
      is rendered as inline code, using `derivation <name>` for derivations.
    - Strings are returned unchanged.
    - Lists and attribute sets are traversed recursively.
    - Functions are rendered as a display of their arguments, with `?` suffix for arguments that have defaults.
    - All other values are returned unchanged.
  */
  fixupDocValues =
    {
      processTypedText ? v: v,
    }@opts:
    v:
    if v ? _type && v ? text then
      if lib.isFunction processTypedText then
        processTypedText v
      else
        throw "wlib.docs.fixupDocValues: processTypedText passed to first argument must be a function"
    else if lib.isStringLike v && !builtins.isString v then
      "`‹${if v ? name then "derivation ${v.name}" else v}›`"
    else if builtins.isString v then
      v
    else if builtins.isList v then
      map (wlib.docs.fixupDocValues opts) v
    else if lib.isFunction v then
      "`‹function with arguments ${
        lib.pipe v [
          lib.functionArgs
          (lib.mapAttrsToList (n: v: "${n}${lib.optionalString v "?"}"))
          (builtins.concatStringsSep ", ")
        ]
      }›`"
    else if builtins.isAttrs v then
      builtins.mapAttrs (_: wlib.docs.fixupDocValues opts) v
    else
      v;

  /**
    Produces a JSON representation of the documentation for an evaluated wrapper module.

    Takes the same arguments as `normWrapperDocs`:

    ```nix
    {
      options,
      transform ? null,
      includeCore ? true,
      prefix ? false,
      processTypedText ? v: v,
    }:
    ```

    - `options`: The evaluated options set from a wrapper module.
    - `transform`: A function applied to each option, returning a list of
      options. Defaults to omitting `_module` options.
    - `includeCore`: Whether to include the core module in the output. Defaults
      to `true`.
    - `prefix`: Passed to `options.extendModules` when it is `null` or a list.
      Defaults to `false`.
    - `processTypedText`: Passed directly to `fixupDocValues`.

    The options are normalized with `normWrapperDocs`, passed through
    `fixupDocValues` function, and then serialized with `builtins.toJSON`.

    Returns a JSON string with its string context discarded.
  */
  wrapperModuleJSON =
    {
      options,
      transform ? null,
      includeCore ? true,
      prefix ? false,
      processTypedText ? v: v,
    }:
    lib.pipe
      {
        inherit
          options
          includeCore
          transform
          prefix
          ;
      }
      [
        wlib.docs.normWrapperDocs
        (wlib.docs.fixupDocValues { inherit processTypedText; })
        builtins.toJSON
        builtins.unsafeDiscardStringContext
      ];
}
