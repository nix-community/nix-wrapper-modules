{ lib, wlib }:
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
  toKdl 2 "  " 0 value
