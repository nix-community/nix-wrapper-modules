# From home-manager: https://github.com/nix-community/home-manager/blob/master/modules/lib/dag.nix
# A generalization of Nixpkgs's `strings-with-deps.nix`.
#
# The main differences from the Nixpkgs version are
#
#  - not specific to strings, i.e., any payload is OK,
#
#  - the addition of the function `entryBefore` indicating a "wanted
#    by" relationship.
#
# The main differences from this version and the home-manager version are
#
# It looks nothing like it anymore
{ wlib, lib }:
let
  inherit (builtins)
    isAttrs
    attrValues
    elem
    all
    head
    tail
    length
    isString
    isBool
    mapAttrs
    isList
    toJSON
    ;
  inherit (lib)
    mkOption
    optionals
    isFunction
    types
    ;
  inherit (lib.lists) toposort;
  inherit (wlib.dag)
    isEntry
    entryBetween
    entriesBetween
    topoSort
    gmap
    dagToDal
    mkDagEntry
    dagNameModule
    unwrapSort
    pushDownDagNames
    specBetween
    specAfter
    specsBetween
    ;
  mkDagEntryModule =
    settings: elemType:
    let
      dataOptFn =
        if isFunction (settings.dataTypeFn or null) then
          args: { type = settings.dataTypeFn elemType args; }
        else
          _: { type = elemType; };
    in
    wlib.types.specWith {
      specialArgs = settings.specialArgs or { };
      class = settings.class or null;
      description = settings.description or null;
      mainField = settings.mainField or null;
      dontConvertFunctions = settings.dontConvertFunctions or null;
      modules = [
        (mkDagEntry {
          dataOptFn = if isFunction (settings.dataOptFn or null) then settings.dataOptFn else dataOptFn;
          defaultNameFn =
            if isFunction (settings.defaultNameFn or null) then settings.defaultNameFn else null;
          readOnlyName = if isBool (settings.readOnlyName or null) then settings.readOnlyName else false;
          isDal = if isBool (settings.isDal or null) then settings.isDal else false;
        })
      ]
      ++ optionals (elemType.name == "submodule") [ dagNameModule ]
      ++ optionals (isList (settings.modules or null)) settings.modules;
    };
in
{
  /**
    Arguments:
    - `settings`:
        - `defaultNameFn ? ({ config, name, isDal, ... }@moduleArgs: if isDal then null else name)`:
          Function to compute the default `name` for entries. Recieves the submodule arguments.
        - `dataTypeFn` ? `(elemType: { config, name, isDal, ... }@moduleArgs: elemType)`:
          Can be used if the type of the `data` field needs to depend upon the submodule arguments.
        - `readOnlyName` ? `false`: sets readOnly for the `name` option for the spec.
        - ...other arguments for `wlib.types.specWith` (`modules`, `specialArgs`, etc...)
          Passed through to configure submodules in the DAG entries.

    - `elemType`: `type`
      The type of the DAG entries’ `data` field. You can provide the type, OR an entry for each item.
      In the resulting `config.optionname` value, all items are normalized into entries.

    Notes:
    - `dagWith` accepts an attrset as its first parameter (the `settings`) **before** `elemType`.
    - To add extra type-checked fields, use the `modules` attribute, which is passed through to `wlib.types.specWith`.
      The allowed dag fields will be automatically generated from the base set of modules passed.
    - The `config.optionname` value from the associated option will be normalized so that all items become valid DAG entries.
    - If `elemType` is a `submodule` or `spec`, a `parentName` argument will automatically be injected to access the actual attribute name.
  */
  dagWith =
    settings: elemType: types.attrsOf (mkDagEntryModule (settings // { isDal = false; }) elemType);

  /**
    Arguments:
    - `settings`:
        - `defaultNameFn ? ({ config, name, isDal, ... }@moduleArgs: if isDal then null else name)`:
          Function to compute the default `name` for entries. Recieves the submodule arguments.
        - `dataTypeFn` ? `(elemType: { config, name, isDal, ... }@moduleArgs: elemType)`:
          Can be used if the type of the `data` field needs to depend upon the submodule arguments.
        - `readOnlyName` ? `false`: sets readOnly for the `name` option for the spec.
        - ...other arguments for `wlib.types.specWith` (`modules`, `specialArgs`, etc...)
          Passed through to configure submodules in the DAG entries.

    - `elemType`: `type`
      The type of the DAL entries’ `data` field. You can provide the type, OR an entry for each item.
      In the resulting `config.optionname` value, all items are normalized into entries.

    Notes:
    - `dalWith` accepts an attrset as its first parameter (the `settings`) **before** `elemType`.
    - To add extra type-checked fields, use the `modules` attribute, which is passed through to `wlib.types.specWith`.
      The allowed dag fields will be automatically generated from the base set of modules passed.
    - The `config.optionname` value from the associated option will be normalized so that all items become valid DAG entries.
    - If `elemType` is a `submodule` or `spec`, a `parentName` argument will automatically be injected to access the actual attribute name.
  */
  dalWith =
    settings: elemType: types.listOf (mkDagEntryModule (settings // { isDal = true; }) elemType);

  /**
    Arguments:

    ```nix
    {
      dataOptFn, # <- receives the submodule arguments. Returns a set for `lib.mkOption` (`internal = true` will be added unless you set it otherwise)
      defaultNameFn ? { name, isDal, ... }@moduleArgs: if isDal then null else name,
      isDal ? false, # <- added to `config._module.args`
    }:
    ```

    `dataOptFn` receives `config`, `options`, `name`, and `isDal`. Returns a set for `lib.mkOption`

    Creates a module with a `name`, `data`, `before`, and `after` field,
    which can be passed to `wlib.types.specWith` or `wlib.types.spec`,
    to create a spec type which can be used with all the `wlib.dag` functions.
  */
  mkDagEntry =
    {
      dataOptFn,
      defaultNameFn ? { name, isDal, ... }@moduleArgs: if isDal then null else name,
      readOnlyName ? false,
      isDal ? false,
    }@settings:
    { name, isDal, ... }@args:
    {
      config._module.args.isDal = if isBool (settings.isDal or null) then settings.isDal else false;
      options = {
        data = mkOption ({ internal = true; } // dataOptFn args);
        name = mkOption {
          internal = true;
          type = types.nullOr types.str;
          ${if readOnlyName == true then "readOnly" else null} = true;
          default =
            if isFunction defaultNameFn then
              defaultNameFn args
            else if isDal then
              null
            else
              name;
        };
        before = mkOption {
          internal = true;
          type = with types; listOf str;
          default = [ ];
        };
        after = mkOption {
          internal = true;
          type = with types; listOf str;
          default = [ ];
        };
      };
    };

  /**
    If, when constructing your own DAG type with `mkDagEntry`, your `data` field accepts submodules, you should also supply this module to `specWith`
    in order to set `config.data._module.args.dagName`.

    You would do this because the name argument of that submodule will receive the field it was in,
    not the one from the parent `attrsOf` type.

    If you use `dagWith` or `dalWith`, this is done for you for `submodule`
  */
  dagNameModule =
    { config, name, ... }:
    {
      config.data._module.args.dagName = config.name or name;
    };

  /*
    Takes an attribute set or list containing attrsets with (optional)
    `name`, `before` and `after` fields.

    It then sorts them into a topologically sorted list of
    entries.

    It does not perform any normalization of the entries themselves.

    Internally this function uses the `toposort` function in
    `<nixpkgs/lib/lists.nix>` and it returns the same thing.

    It returns an object which is like a "result"

    Specifically, the result on success is

    ```nix
       { result = [ { name = ?; data = ?; … } … ] }
    ```

    For example

    ```nix
       nix-repl> topoSort {
                   a = entryAnywhere "1";
                   b = entryAfter [ "a" "c" ] "2";
                   c = entryBefore [ "d" ] "3";
                   d = entryBefore [ "e" ] "4";
                   e = entryAnywhere "5";
                 } == {
                  result = [
                    { data = "1"; name = "a"; after = [ ]; before = [ ]; }
                    { data = "3"; name = "c"; after = [ ]; before = [ "d" ]; }
                    { data = "2"; name = "b"; after = [ "a" "c" ]; before = [ ]; }
                    { data = "4"; name = "d"; after = [ ]; before = [ "e" ]; }
                    { data = "5"; name = "e"; after = [ ]; before = [ ]; }
                  ];
                 }
       true
    ```

    And the result on error is

    ```nix
       {
         cycle = [ { after = ?; name = ?; data = ? } … ];
         loops = [ { after = ?; name = ?; data = ? } … ];
       }
    ```

    For example

    ```nix
       nix-repl> topoSort {
                   a = entryAnywhere "1";
                   b = entryAfter [ "a" "c" ] "2";
                   c = entryAfter [ "d" ] "3";
                   d = entryAfter [ "b" ] "4";
                   e = entryAnywhere "5";
                 } == {
                  cycle = [
                    { data = "2"; name = "b"; after = [ "a" "c" ]; before = [ ]; }
                    { data = "3"; name = "c"; after = [ "d" ]; before = [ ]; }
                    { data = "4"; name = "d"; after = [ "b" ]; before = [ ]; }
                  ];
                  loops = [
                    { data = "2"; name = "b"; after = [ "a" "c" ]; before = [ ]; }
                  ];
                }
       true
    ```
  */
  topoSort =
    dag:
    let
      before =
        a: b:
        let
          aName = a.name or null;
          bName = b.name or null;
        in
        (aName != null && elem aName (b.after or [ ])) || (bName != null && elem bName (a.before or [ ]));
    in
    toposort before (if isList dag then dag else dagToDal dag);

  /**
    Convenience function for resolving a DAG or DAL and getting the result in a sorted list of DAG entries

    `wlib.dag.unwrapSort "name_for_error" { a = { before = [ "b" ]; }; b = { data = 1; }; }`

    The result is a sorted DAL, the result field from calling `wlib.dag.topoSort`

    Accepts the same types in its dag argument as `wlib.dag.topoSort`.

    But it returns the resulting list directly, and throws an error message if there is a cycle
  */
  unwrapSort =
    name: dag:
    let
      sortedDag = topoSort dag;
    in
    if sortedDag ? result then
      sortedDag.result
    else
      throw ("Dependency cycle in ${toString name}: " + toJSON sortedDag);

  /**
    Same as unwrapSort but its argument is a set and it optionally accepts a function to map over the result

    Arguments:
    ```nix
    {
      dag,
      name ? "DAG", # for error message
      mapIfOk ? null,
    }
    ```
  */
  sortAndUnwrap =
    {
      name ? "DAG",
      dag,
      mapIfOk ? null,
    }:
    if isFunction mapIfOk then map mapIfOk (unwrapSort name dag) else unwrapSort name dag;

  /**
    converts a DAG to a DAL

    Accepts almost the same types as `wlib.dag.topoSort`.

    Except it requires the DAG form.

    It is the normalization function used by `topoSort`
    when the argument is not a list prior to sorting the list.
  */
  dagToDal = dag: attrValues (pushDownDagNames dag);

  /**
    Takes a DAG (set of sets) and adds the name field to the internal set if not already present and a string
  */
  pushDownDagNames = builtins.mapAttrs (
    n: v:
    v
    // {
      name =
        if isString (v.name or null) then
          v.name
        else if isString n then
          n
        else
          null;
    }
  );

  /**
    Determines whether a value is a valid DAG entry (allows extra values)

    Will return true if the item meets the following criteria:

    Has a data field.
    If it has a name field that field is a string.
    If it has a before or after field that field is a list of strings.

    It allows entries to have extra values not mentioned above.
  */
  isEntry =
    e:
    e ? data
    && (if e ? after then isList e.after && all isString e.after else true)
    && (if e ? before then isList e.before && all isString e.before else true)
    && (if e ? name then e.name == null || isString e.name else true);

  /**
    determines whether a value is of the attrset type and all values meet the criteria of `wlib.dag.isEntry`

    Allows entries to have extra values
  */
  isDag = dag: isAttrs dag && all isEntry (attrValues dag);

  /**
    determines whether a value is of the list type and all values meet the criteria of `wlib.dag.isEntry`
  */
  isDal = dal: isList dal && all isEntry dal;

  /**
    Applies a function to each element of the given DAL.

    Requires values to meet the criteria of `wlib.dag.isEntry`
  */
  lmap = f: map (v: v // { data = f v.data; });

  /**
    Applies a function to each element of the given DAG.

    Requires values to meet the criteria of `wlib.dag.isEntry`
  */
  gmap = f: mapAttrs (n: v: v // { data = f n v.data; });

  /**
    wlib.dag.gmap but returns the result as a DAL

    Requires values to meet the criteria of `wlib.dag.isEntry`
  */
  mapDagToDal = f: dag: dagToDal (gmap f dag);

  /**
    Adds `before` and `after` dependencies to a spec.

    This is similar to `entryBetween`, but instead of constructing a new
    entry it augments an existing spec. Any existing `before` or `after`
    fields on the spec are preserved and extended.

    Arguments:
    - `before`: `[ string ]`
      Additional nodes that the spec should appear before.
    - `after`: `[ string ]`
      Additional nodes that the spec should appear after.
    - `spec`: `attrset`
      The spec to modify.

    Returns the spec with merged dependency fields.
  */
  specBetween =
    before: after: spec:
    spec
    // {
      before = spec.before or [ ] ++ before;
      after = spec.after or [ ] ++ after;
    };

  /**
    Adds `after` dependencies to a spec.

    Equivalent to:

    ```nix
    specBetween [ ] after spec
    ```

    Existing dependency fields on the spec are preserved and extended.
  */
  specAfter = specBetween [ ];

  /**
    Adds `before` dependencies to a spec.

    Equivalent to:

    ```nix
    specBetween before [ ] spec
    ```

    Existing dependency fields on the spec are preserved and extended.
  */
  specBefore = before: specBetween before [ ];

  /**
    Creates a DAG entry with specified `before` and `after` dependencies.
  */
  entryBetween = before: after: data: { inherit data before after; };

  /**
    Create a DAG entry with no particular dependency information.
  */
  entryAnywhere = entryBetween [ ] [ ];

  /**
    Convenience function to create a DAG entry that should come after certain nodes.
  */
  entryAfter = entryBetween [ ];

  /**
    Convenience function to create a DAG entry that should come before certain nodes.
  */
  entryBefore = before: entryBetween before [ ];

  /**
    Given a list of specs (attribute sets with stuff in them, and optional `name`, `before`, and `after` fields), places them sequentially within the DAG.

    This is approximately the opposite of `wlib.dag.dagToDal`.

    Each generated node receives a name of the form:

    ```
    "${tag}-${index}"
    ```

    If a spec already has a `name` field it will be used instead.

    The specs are chained via their before and after fields so that their order in the list is preserved.
    The entire sequence can also be constrained relative to other DAG
    nodes using the `before` and `after` arguments.

    Arguments:
    - `tag`: `string`
      Prefix used when generating names.
    - `before`: `[ string ]`
      Nodes that the first generated entry must appear before.
    - `after`: `[ string ]`
      Nodes that the first generated entry must appear after.
    - `entries`: `[ attrset ]`
      Specs to insert into the DAG.

    Returns a DAG (attribute set) containing the generated entries.
  */
  specsBetween =
    tag:
    let
      go =
        i: before: after: entries:
        let
          current = head entries;
          name = current.name or "${tag}-${toString i}";
        in
        if entries == [ ] then
          { }
        else if length entries == 1 then
          {
            ${name} = specBetween before after current // {
              inherit name;
            };
          }
        else
          {
            ${name} = specAfter after current // {
              inherit name;
            };
          }
          // go (i + 1) before [ name ] (tail entries);
    in
    go 0;

  /**
    defined as:

    ```nix
    tag: before: after: entries:
    wlib.dag.specsBetween tag before after (map (data: { inherit data; }) entries)
    ```
  */
  entriesBetween =
    tag: before: after: entries:
    specsBetween tag before after (map (data: { inherit data; }) entries);

  /**
    Convenience wrapper around `specsBetween` that inserts a sequence
    of specs without adding any external ordering constraints.

    The generated entries will still be chained relative to each other
    so that their order in the input list is preserved.

    Equivalent to:

    ```nix
    tag: specsBetween tag [ ] [ ]
    ```

    Arguments:
    - `tag`: `string`
      Prefix used when generating names.
  */
  specsAnywhere = tag: specsBetween tag [ ] [ ];

  /**
    Convenience wrapper around `specsBetween` that inserts a sequence
    of specs which must appear after the given nodes.

    Equivalent to:

    ```nix
    tag: after: specsBetween tag [ ] after
    ```

    Arguments:
    - `tag`: `string`
      Prefix used when generating names.
    - `after`: `[ string ]`
      Nodes that the first generated entry must appear after.
  */
  specsAfter = tag: specsBetween tag [ ];

  /**
    Convenience wrapper around `specsBetween` that inserts a sequence
    of specs which must appear before the given nodes.

    Equivalent to:

    ```nix
    tag: before: specsBetween tag before [ ]
    ```

    Arguments:
    - `tag`: `string`
      Prefix used when generating names.
    - `before`: `[ string ]`
      Nodes that the first generated entry must appear before.
  */
  specsBefore = tag: before: specsBetween tag before [ ];

  /**
    Convenience wrapper around `entriesBetween` that inserts a sequence
    of entries without adding any external ordering constraints.

    Equivalent to:

    ```nix
    tag: entries: entriesBetween tag [ ] [ ] entries
    ```

    Arguments:
    - `tag`: `string`
      Prefix used when generating names.
    - `entries`: `[ any ]`
      Payload values that will be converted into DAG entries.
  */
  entriesAnywhere = tag: entriesBetween tag [ ] [ ];

  /**
    Convenience wrapper around `entriesBetween` that inserts a sequence
    of entries which must appear after the given nodes.

    Equivalent to:

    ```nix
    tag: after: entries: entriesBetween tag [ ] after entries
    ```

    Arguments:
    - `tag`: `string`
      Prefix used when generating names.
    - `after`: `[ string ]`
      Nodes that the first generated entry must appear after.
    - `entries`: `[ any ]`
      Payload values that will be converted into DAG entries.
  */
  entriesAfter = tag: entriesBetween tag [ ];

  /**
    Convenience wrapper around `entriesBetween` that inserts a sequence
    of entries which must appear before the given nodes.

    Equivalent to:

    ```nix
    tag: before: entries: entriesBetween tag before [ ] entries
    ```

    Arguments:
    - `tag`: `string`
      Prefix used when generating names.
    - `before`: `[ string ]`
      Nodes that the first generated entry must appear before.
    - `entries`: `[ any ]`
      Payload values that will be converted into DAG entries.
  */
  entriesBefore = tag: before: entriesBetween tag before [ ];
}
