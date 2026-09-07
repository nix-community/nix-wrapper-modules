{
  lib,
  wlib,
  defaultOptionTransform,
}:
{
  options,
  prefix ? false,
  transform ? null,
  includeCore ? true,
  ...
}:
let
  evaluated =
    options.extendModules.value or (
      _: throw "nix-wrapper-modules docgen error: the options set passed was not from a wrapper module!"
    )
    { ${if prefix == null || builtins.isList prefix then "prefix" else null} = prefix; };
in
let
  inherit (evaluated) options graph;
  collectOptions =
    {
      options ? { },
      transform ? x: [ x ],
    }:
    let
      # Generate DocBook documentation for a list of packages. This is
      # what `relatedPackages` option of `mkOption` from
      # ../../../lib/options.nix influences.
      #
      # Each element of `relatedPackages` can be either
      # - a string:  that will be interpreted as an attribute name from `pkgs` and turned into a link
      #              to search.nixos.org,
      # - a list:    that will be interpreted as an attribute path from `pkgs` and turned into a link
      #              to search.nixos.org,
      # - an attrset: that can specify `name`, `path`, `comment`
      #   (either of `name`, `path` is required, the rest are optional).
      #
      # NOTE: No checks against `pkgs` are made to ensure that the referenced package actually exists.
      # Such checks are not compatible with option docs caching.
      genRelatedPackages =
        packages: optName:
        let
          unpack =
            p:
            if lib.isString p then
              { name = p; }
            else if lib.isList p then
              { path = p; }
            else
              p;
          describe =
            args:
            let
              title = args.title or null;
              name = args.name or (lib.concatStringsSep "." args.path);
            in
            ''
              - [${lib.optionalString (title != null) "${title} aka "}`pkgs.${name}`](
                  https://search.nixos.org/packages?show=${name}&sort=relevance&query=${name}
                )${lib.optionalString (args ? comment) "\n\n  ${args.comment}"}
            '';
        in
        lib.concatMapStrings (p: describe (unpack p)) packages;
    in
    lib.pipe options [
      lib.optionAttrSetToDocList
      (builtins.concatMap transform)
      (map (
        opt:
        opt
        // lib.optionalAttrs (opt ? relatedPackages && opt.relatedPackages != [ ]) {
          relatedPackages = genRelatedPackages opt.relatedPackages opt.name;
        }
      ))
    ];

  get-meta =
    descs: authors:
    let
      zipper = builtins.zipAttrsWith (
        file: xs: {
          inherit file;
          description = builtins.foldl' (
            acc: v:
            acc
            // {
              ${if v.desc.pre or "" != "" then "pre" else null} =
                (if acc.desc.pre or "" != "" then acc.desc.pre + "\n\n" else "") + v.desc.pre;
              ${if v.desc.post or "" != "" then "post" else null} =
                (if acc.desc.post or "" != "" then acc.desc.post + "\n\n" else "") + v.desc.post;
            }
          ) { } xs;
          maintainers = builtins.filter (v: v != null) (map (v: v.ppl or null) xs);
        }
      );
      descriptions = map (v: {
        ${v.file} = {
          desc = v;
        };
      }) descs;
      maintainers = map (v: {
        ${v.file} = {
          ppl = v;
        };
      }) authors;
    in
    zipper (descriptions ++ maintainers);

  # associate module files from graph with items in meta-info
  # all imports get grouped until the next one with an item in meta-info is found
  # merge the associated file paths into your meta-info for each item
  associate =
    let
      mergemeta =
        meta: file: new:
        meta
        // {
          ${file} = meta.${file} or { } // {
            associated = meta.${file}.associated or [ ] ++ [ new ];
          };
        };
      associate' =
        current:
        builtins.foldl' (
          acc: v:
          if acc.${v.file} or null != null then
            associate' v.file (mergemeta acc v.file v.file) v.imports
          else if current == null then
            associate' current (mergemeta acc v.file v.file) v.imports
          else
            associate' current (mergemeta acc current v.file) v.imports
        );
    in
    associate' null;

  # This will be used to sort the options from collectOptions
  modules-by-meta =
    lib.pipe (get-meta options.meta.description.value options.meta.maintainers.value)
      [
        (v: associate v graph)
        (lib.mapAttrsToList (file: v: if v ? file then v else v // { inherit file; }))
      ];

  partitioned =
    lib.partition (v: v.internal or false == true || v.visible or true == false)
      (collectOptions {
        inherit options;
        transform = if lib.isFunction transform then transform else defaultOptionTransform;
      });
  invisible = lib.partition (v: v.internal or false == true) partitioned.right;

  anon_name = "<unknown-file>";
  groupByDecl =
    opts:
    builtins.zipAttrsWith (n: xs: xs) (
      builtins.concatMap (
        v:
        map (n: {
          ${n} = v;
          # NOTE: what to do with items without anything in declarations? That can happen if the type definition is messed up.
          # Right now we group them all under "<unknown-file>"
        }) (if v.declarations or [ ] == [ ] then [ anon_name ] else v.declarations)
      ) opts
    );

  internal = groupByDecl invisible.right;
  hidden = groupByDecl invisible.wrong;
  visible = groupByDecl partitioned.wrong;

  collectAssociatedOptions =
    visiblity: groupedOptions:
    {
      unassociated ? { },
      modules-by-meta,
    }:
    let
      isAssociated = file: module: builtins.any (n: lib.hasInfix n file) (module.associated or [ ]);
      associations = builtins.mapAttrs (
        file: _: lib.lists.findFirstIndex (isAssociated file) null modules-by-meta
      ) groupedOptions;
    in
    {
      modules-by-meta = lib.imap0 (
        i: module:
        let
          opts =
            module.${visiblity} or [ ]
            ++ builtins.concatLists (
              lib.mapAttrsToList (file: index: if index == i then groupedOptions.${file} else [ ]) associations
            );
        in
        module
        // {
          ${if opts != [ ] then visiblity else null} = opts;
        }
      ) modules-by-meta;
      unassociated = unassociated // {
        ${visiblity} =
          unassociated.${visiblity} or [ ]
          ++ builtins.concatLists (
            lib.mapAttrsToList (file: index: if index == null then groupedOptions.${file} else [ ]) associations
          );
      };
    };

in
lib.pipe { inherit modules-by-meta; } [
  (collectAssociatedOptions "visible" visible)
  (collectAssociatedOptions "hidden" hidden)
  (collectAssociatedOptions "internal" internal)
  (
    { unassociated, modules-by-meta }:
    let
      modules-filtered = builtins.filter (
        v: v.visible or [ ] != [ ] || v.hidden or [ ] != [ ] || v.internal or [ ] != [ ]
      ) modules-by-meta;
      anon_module = {
        file = anon_name;
        ${if unassociated.visible or [ ] != [ ] then "visible" else null} = unassociated.visible or [ ];
        ${if unassociated.hidden or [ ] != [ ] then "hidden" else null} = unassociated.hidden or [ ];
        ${if unassociated.internal or [ ] != [ ] then "internal" else null} = unassociated.internal or [ ];
      };
    in
    lib.reverseList modules-filtered
    ++ lib.optional (
      anon_module.visible or [ ] != [ ]
      || anon_module.hidden or [ ] != [ ]
      || anon_module.internal or [ ] != [ ]
    ) anon_module
  )
  (
    normed:
    if builtins.isBool includeCore && includeCore == true then
      normed
    else
      builtins.filter (v: v.file != wlib.core) normed
  )
]
