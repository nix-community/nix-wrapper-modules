{ lib, wlib }: {
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

    The top level argument to `wlib.generators.toKdl` may also be a function, but it is slightly different
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
  toKdl =
    let
      inherit (builtins) isList isAttrs toJSON;
      listOfNodes = l: isList l && builtins.all isAttrs l;
      toKdlNode =
        version: indent_str: i: n: val:
        let
          mkArgs =
            args:
            let
              toVal =
                v:
                if version == 2 && v == null then
                  "#null"
                else if version == 2 && builtins.isBool v then
                  if v then "#true" else "#false"
                else if lib.isFunction v then
                  let
                    res = lib.fix v;
                  in
                  lib.optionalString (res ? type) "(${toString res.type})"
                  + lib.optionalString (res ? content && !res ? custom) "${toJSON res.content}"
                  + lib.optionalString (res ? custom) res.custom
                else if isAttrs v || isList v then
                  toJSON (toJSON v)
                else
                  toJSON v;
              mkAttrsOrVal =
                attrs:
                if isAttrs attrs then
                  lib.concatMapAttrsStringSep " " (n: v: "${toJSON n}=${toVal v}") attrs
                else
                  toVal attrs;
            in
            if isList args then
              let
                partitioned = lib.partition isAttrs args;
                args' = if version == 2 then partitioned.wrong ++ partitioned.right else args;
              in
              lib.concatMapStringsSep " " mkAttrsOrVal args'
            else
              mkAttrsOrVal args;
          indent = wlib.repeatStr indent_str;
          special = lib.isFunction val;
          res = if special then lib.fix val else val;
          v = if special then res.content or null else res;
          nodetype = if res ? type then "(${toString res.type})" else "";
          attrs = if special && res ? props then mkArgs res.props else "";
        in
        if special && res ? custom then
          res.custom {
            indent = indent_str;
            lvl = i;
            name = n;
          }
        else if isAttrs v then
          ''
            ${indent i}${nodetype}${toJSON n} ${attrs} {
            ${lib.concatMapAttrsStringSep "\n" (toKdlNode version indent_str (i + 1)) v}
            ${indent i}}''
        else if listOfNodes v then
          ''
            ${indent i}${nodetype}${toJSON n} ${attrs} {
            ${lib.concatMapStringsSep "\n" (lib.concatMapAttrsStringSep "\n" (
              toKdlNode version indent_str (i + 1)
            )) v}
            ${indent i}}''
        else if special then
          "${indent i}${nodetype}${toJSON n} ${attrs}"
        else
          "${indent i}${nodetype}${toJSON n} ${mkArgs v}";
      toKdl =
        version: indent: i: value:
        if isAttrs value then
          lib.concatMapAttrsStringSep "\n" (toKdlNode version indent i) value
        else if listOfNodes value then
          lib.concatMapStringsSep "\n" (lib.concatMapAttrsStringSep "\n" (toKdlNode version indent i)) value
        else
          throw "ERROR wlib.toKdl: argument to wlib.toKdl is expected to be an attrset or a list of attrsets which represent the top level nodes of a kdl file!";
    in
    value:
    if lib.isFunction value then
      let
        res = lib.fix value;
      in
      toKdl (res.version or 2) (res.indent or "  ") (res.lvl or 0) res.content
    else
      toKdl 2 "  " 0 value;

  /**
      Converts a Nix value to a Hypr conf string.

      Parameters:
      - `attrs`: Attrset of hypr conf keywords assigned either a value (string, boolean, number), a list of such values or an attrset that has the same structure:
          value: a keyword statement is generated
          list: for each value a separate keyword statement is generated
          attrset: a section to configure variables is generated
      - `indentLevel`: (optional, default: 0) Start at a custom indent level
      - `importantPrefixes`: (optional, default: [ "$" ]) Prefixes of keywords that should be generated first

      Example:
      ```nix
        toHyprconf {
          attrs = {
            general = {
              border_size = 2;
              "col.active_border" = "rgba(FF0000EE)";
            };

            bind = [
              "$mod, H, movefocus, l"
              "$mod, J, movefocus, d"
              "$mod, K, movefocus, u"
              "$mod, L, movefocus, r"
            ];

            "$mod" = "SUPER";
          };
        }
      ```

      will generate the following hypr conf

      ```
      $mod = SUPER

      general {
        border_size = 2
        col.active_border = rgba(FF0000EE)
      }

      bind = $mod, H, movefocus, l
      bind = $mod, J, movefocus, d
      bind = $mod, K, movefocus, u
      bind = $mod, L, movefocus, r
      ```

      from: [home-manager/modules/lib/generators.nix](https://github.com/nix-community/home-manager/blob/8a423e444b17dde406097328604a64fc7429e34e/modules/lib/generators.nix)
  */
  toHyprconf =
    {
      attrs,
      indentLevel ? 0,
      importantPrefixes ? [ "$" ],
    }:
    let
      inherit (lib)
        all
        concatMapStringsSep
        concatStrings
        concatStringsSep
        filterAttrs
        foldl
        generators
        hasPrefix
        isAttrs
        isList
        mapAttrsToList
        replicate
        attrNames
        ;

      initialIndent = concatStrings (replicate indentLevel "  ");

      toHyprconf' =
        indent: attrs:
        let
          isImportantField =
            n: _: foldl (acc: prev: if hasPrefix prev n then true else acc) false importantPrefixes;
          importantFields = filterAttrs isImportantField attrs;
          withoutImportantFields = fields: removeAttrs fields (attrNames importantFields);

          allSections = filterAttrs (_n: v: isAttrs v || isList v) attrs;
          sections = withoutImportantFields allSections;

          mkSection =
            n: attrs:
            if isList attrs then
              let
                separator = if all isAttrs attrs then "\n" else "";
              in
              (concatMapStringsSep separator (a: mkSection n a) attrs)
            else if isAttrs attrs then
              ''
                ${indent}${n} {
                ${toHyprconf' "  ${indent}" attrs}${indent}}
              ''
            else
              toHyprconf' indent { ${n} = attrs; };

          mkFields = generators.toKeyValue {
            listsAsDuplicateKeys = true;
            inherit indent;
          };

          allFields = filterAttrs (_n: v: !(isAttrs v || isList v)) attrs;
          fields = withoutImportantFields allFields;
        in
        mkFields importantFields
        + concatStringsSep "\n" (mapAttrsToList mkSection sections)
        + mkFields fields;
    in
    toHyprconf' initialIndent attrs;
}
