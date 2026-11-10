{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  buildModuleDocs =
    {
      prefix ? "",
      title ? null,
      package ? null,
      descriptionIncluded ?
        type: i: mod:
        if type == "pre" then true else i == 1,
      ...
    }@args:
    name: module:
    "${config.wrapperModuleStyleTag}\n\n"
    + (if title != null then "# ${title}\n\n" else "# `${prefix}${name}`\n\n")
    + wlib.docs.wrapperModuleMD (
      removeAttrs args [
        "title"
        "prefix"
        "package"
      ]
      // {
        inherit
          (wlib.evalModule [
            module
            {
              _module.check = false;
              inherit pkgs;
              ${if package != null then "package" else null} = package;
            }
          ])
          options
          ;
        ${if descriptionIncluded != null then "descriptionIncluded" else null} = descriptionIncluded;
      }
    );

  # copied from nix-wrapper-modules/lib/docs/rendermd.nix
  # used here for flake parts module documentation rendering
  renderOption =
    opt:
    let
      mkOptField =
        opt: n: desc:
        lib.optionalString (opt ? "${n}" && lib.isStringLike opt.${n}) (
          lib.optionalString (desc != "") "${desc}\n" + "${opt.${n}}\n\n"
        );
      declaredBy =
        { declarations, ... }:
        let
          removeViaOption =
            str:
            let
              match = builtins.match "^(.*), via option .*$" str;
            in
            if match != null then builtins.elemAt match 0 else str;
          linkDest =
            v:
            if lib.hasPrefix wlib.modulesPath v then
              "https://github.com/nix-community/nix-wrapper-modules/blob/main"
              + lib.removePrefix wlib.modulesPath (removeViaOption (toString v))
            else
              toString v;
          linkName = v: lib.removeSuffix "/module.nix" (lib.removePrefix "${wlib.modulesPath}/" (toString v));
        in
        builtins.concatStringsSep "\n" (map (v: "- [${linkName v}](${linkDest v})") declarations);
    in
    ''
      ### `${lib.options.showOption (opt.loc or [ ])}`

      ${mkOptField opt "description" ""}${mkOptField opt "relatedPackages" "Related packages:\n"}${
        mkOptField opt "type" "Type:${lib.optionalString (opt.readOnly or false == true) " (read-only)"}"
      }${
        let
          # default can depend on another field without a default value
          res = builtins.tryEval (mkOptField opt "default" "Default:");
        in
        if res.success or false then res.value else ""
      }${mkOptField opt "example" "Example:"}${
        lib.optionalString (opt.declarations or [ ] != [ ]) ''
          Declared by:

          ${declaredBy opt}

        ''
      }
    '';
in
{
  imports = [
    wlib.docs.wrapperModuleMdBookStyle
  ];
  config.outputs = [
    "out"
    "generated"
  ];
  options.warningsAreErrors = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether warnings in the docgen should be treated as errors (i.e. missing descriptions)";
  };
  # write these docs from __structuredAttrs json file to a new output and mark that output with unsafeDiscardReferences
  # this ensures that, even if any references slipped through, we will not attempt to build them.
  # However, this should not be possible, as all references should be discarded by the docgen itself.
  # This could have been done via constructFiles and setting the output to generated,
  # but this gives us nice config.drv attribute sets to iterate over to construct our final book
  config.drv.__structuredAttrs = true;
  config.drv.unsafeDiscardReferences.generated = true;
  config.buildCommand.getModDocs = /* bash */ ''
    mkdir -p "$generated/wrapper_docs"
    jq -r '.wrapper_docs | to_entries[] | @base64' "$NIX_ATTRS_JSON_FILE" | while read -r entry; do
      # decode base64 to get JSON safely
      decoded=$(echo "$entry" | base64 --decode)
      echo "$(echo "$decoded" | jq -r '.value')" > "$generated/wrapper_docs/$(echo "$decoded" | jq -r '.key').md"
    done
    mkdir -p "$generated/module_docs"
    jq -r '.module_docs | to_entries[] | @base64' "$NIX_ATTRS_JSON_FILE" | while read -r entry; do
      decoded="$(echo "$entry" | base64 --decode)"
      echo "$(echo "$decoded" | jq -r '.value')" > "$generated/module_docs/$(echo "$decoded" | jq -r '.key').md"
    done
    jq -r '.core_docs' "$NIX_ATTRS_JSON_FILE" > "$generated/core.md"
  '';
  # build and pass the docs via the drv attributes to be grabbed in the build statement above.
  config.drv.module_docs = builtins.mapAttrs (buildModuleDocs {
    prefix = "wlib.modules.";
    package = pkgs.hello;
    includeCore = false;
    inherit (config) warningsAreErrors;
    moduleStartsOpen = _: _: true;
    descriptionStartsOpen =
      _: _: _:
      true;
    descriptionIncluded =
      _: _: _:
      true;
  }) wlib.modules;
  config.drv.wrapper_docs = builtins.mapAttrs (buildModuleDocs {
    prefix = "wlib.wrapperModules.";
    inherit (config) warningsAreErrors;
  }) wlib.wrapperModules;
  config.drv.core_docs = buildModuleDocs {
    package = pkgs.hello;
    inherit (config) warningsAreErrors;
    title = "Core (builtin) Options set";
  } "core" { };

  options.flake-parts-input = lib.mkOption {
    type = lib.types.raw;
    default = { };
    description = "input for flake-parts to make the flake parts docs";
  };
  config.drv.flake_parts_docs =
    let
      evalFlakeModule = config.flake-parts-input.lib.evalFlakeModule or null;
      cfg1 = evalFlakeModule { inputs = { }; } { _module.check = false; };
      cfg = evalFlakeModule { inputs = { }; } {
        _module.check = false;
        imports = [ "${wlib.modulesPath}/parts.nix" ];
        perSystem._module.args.pkgs = pkgs;
      };
      base = lib.optionAttrSetToDocList cfg1.options;
      optDocOut = lib.optionAttrSetToDocList cfg.options;
      namesInFirst = builtins.listToAttrs (
        map (x: {
          name = x.name;
          value = true;
        }) base
      );
      filteredDoc = builtins.filter (
        x: !(namesInFirst.${x.name} or false) && (builtins.all (n: n != "_module") x.loc)
      ) optDocOut;
      fixedUp = wlib.docs.fixupDocValues {
        processTypedText =
          v: if v._type == "literalExpression" then "```nix\n${toString v.text}\n```" else toString v.text;
      } filteredDoc;
      markdownOpts = builtins.concatStringsSep "\n\n" (map renderOption fixedUp);
    in
    lib.optionalString (evalFlakeModule != null) markdownOpts;
}
