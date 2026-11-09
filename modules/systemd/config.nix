{
  config,
  lib,
  wlib,
  pkgs,
  ...
}@top:
let
  sectionsByExtension = {
    service = [
      "Install"
      "Service"
    ];
    socket = [
      "Install"
      "Socket"
    ];
    scope = [ "Scope" ];
    target = [ "Install" ];
    device = [ "Install" ];
    mount = [
      "Install"
      "Mount"
    ];
    timer = [
      "Install"
      "Timer"
    ];
    automount = [
      "Install"
      "Automount"
    ];
    swap = [
      "Install"
      "Swap"
    ];
    path = [
      "Install"
      "Path"
    ];
    slice = [
      "Install"
      "Slice"
    ];
  };
  toSystemdFile =
    ext: value:
    let
      # will filter out top level values outside of headings.
      # these are not valid in systemd files, and we use that for enable and install option.
      # so we filter them out
      filtered = lib.filterAttrs (_: v: builtins.isAttrs v) value;
      invalidSections = lib.pipe filtered [
        builtins.attrNames
        (lib.subtractLists (sectionsByExtension.${ext} ++ [ "Unit" ]))
        (builtins.filter (n: !lib.hasPrefix "X-" n))
      ];
      checked =
        if !sectionsByExtension ? "${ext}" then
          value
        else if invalidSections == [ ] then
          filtered
        else
          throw ''
            nix-wrapper-modules: Systemd `.${ext}` file contains invalid sections: ${builtins.concatStringsSep " " invalidSections}
          '';
    in
    value.prefixedContent or ""
    + lib.generators.toINI {
      listsAsDuplicateKeys = true;
      mkKeyValue =
        k: v: if v == null then "# ${k} is unset" else "${k}=${lib.generators.mkValueStringDefault { } v}";
    } checked
    + value.suffixedContent or "";
  mapped = lib.pipe config.systemd [
    (v: { inherit (v) user system; })
    (lib.mapAttrsToList (
      type:
      lib.flip lib.pipe [
        (v: if !v.enable or false then { } else v)
        (builtins.intersectAttrs sectionsByExtension)
        (lib.mapAttrsToList (
          ext:
          lib.flip lib.pipe [
            (lib.filterAttrs (n: v: v.enable or false))
            (lib.mapAttrsToList (
              name: opts: {
                inherit
                  type
                  ext
                  name
                  opts
                  ;
                inherit (opts) doInstall overwrite;
              }
            ))
          ]
        ))
      ]
    ))
    builtins.concatLists
    builtins.concatLists
    (map (
      v:
      v
      // {
        path = "${placeholder config.outputName}/lib/systemd/${v.type}/${v.name}.${v.ext}";
        links = [ "${placeholder config.outputName}/share/systemd/${v.type}/${v.name}.${v.ext}" ];
        wantedBy =
          let
            val = v.opts.Install.WantedBy or null;
          in
          if builtins.isList val && v.doInstall then val else [ ];
        requiredBy =
          let
            val = v.opts.Install.RequiredBy or null;
          in
          if builtins.isList val && v.doInstall then val else [ ];
        upheldBy =
          let
            val = v.opts.Install.upheldBy or null;
          in
          if builtins.isList val && v.doInstall then val else [ ];
        drvKey = wlib.sanitizeEnvVarName ("systemd_" + v.type + "_" + v.ext + "_" + v.name);
        content = toSystemdFile v.ext v.opts;
      }
    ))
  ];
in
{
  config.drv = builtins.listToAttrs (map (v: lib.nameValuePair v.drvKey v.content) mapped) // {
    passAsFile = map (v: v.drvKey) mapped;
  };
  config.buildCommand.systemd = {
    after = [
      "makeWrapper"
      "constructFiles"
      "symlinkScript"
    ];
    # appends to existing systemd files if they exist
    # otherwise creates them
    data =
      let
        mkFindExisting =
          path: links:
          let
            p = lib.escapeShellArg path;
          in
          builtins.concatStringsSep "\n" (
            [
              ''existingPath=""''
              "if [ -f ${p} ] || [ -L ${p} ]; then"
              "existingPath=${p}"
              "fi"
            ]
            ++ map (
              ln:
              let
                l = lib.escapeShellArg ln;
              in
              ''
                if [ -z "$existingPath" ] && { [ -f ${l} ] || [ -L ${l} ]; }; then
                  existingPath=${l}
                fi
              ''
            ) links
          );
        commands = map (v: ''
          ${lib.optionalString (!v.overwrite) (mkFindExisting v.path v.links)}
          mkdir -p ${lib.escapeShellArg (dirOf v.path)}
          ${
            if v.overwrite then
              ''
                rm -f ${v.path}
                { [ -e "''$${v.drvKey}Path" ] && cat "''$${v.drvKey}Path" || echo "''$${v.drvKey}"; } > ${lib.escapeShellArg v.path}
              ''
            else
              let
                path = lib.escapeShellArg v.path;
              in
              ''
                if [ -n "$existingPath" ]; then
                  path=${path}
                  tempfile="$(mktemp)"
                  mkdir -p "$(dirname "$tempfile")"
                  cat "$(readlink -f "$existingPath")" > "$tempfile"
                  rm -f ${path}
                  cat "$tempfile" > ${path}
                  rm "$tempfile"
                  { [ -e "''$${v.drvKey}Path" ] && cat "''$${v.drvKey}Path" || echo "''$${v.drvKey}"; } >> ${path}
                else
                  { [ -e "''$${v.drvKey}Path" ] && cat "''$${v.drvKey}Path" || echo "''$${v.drvKey}"; } > ${path}
                fi
              ''
          }
          ${builtins.concatStringsSep "\n" (
            map (l: ''
              # If a parent dir is a link to the lib/systemd dir and thus these are the same file, leave it
              if [ ! ${lib.escapeShellArg v.path} -ef ${lib.escapeShellArg l} ]; then
                mkdir -p ${lib.escapeShellArg (dirOf l)}
                rm -f ${lib.escapeShellArg l}
                ln -s ${lib.escapeShellArg v.path} ${lib.escapeShellArg l}
              fi
            '') v.links
          )}
          ${builtins.concatStringsSep "\n" (
            let
              mkInstall = variant: target: ''
                mkdir -p ${lib.escapeShellArg "${placeholder config.outputName}/lib/systemd/${v.type}/${target}.${variant}"}
                ln -sf ${lib.escapeShellArg v.path} \
                  ${lib.escapeShellArg "${placeholder config.outputName}/lib/systemd/${v.type}/${target}.${variant}/${v.name}.${v.ext}"}
                mkdir -p ${lib.escapeShellArg "${placeholder config.outputName}/share/systemd/${v.type}/${target}.${variant}"}
                ln -sf ${lib.escapeShellArg v.path} \
                  ${lib.escapeShellArg "${placeholder config.outputName}/share/systemd/${v.type}/${target}.${variant}/${v.name}.${v.ext}"}
              '';
            in
            map (mkInstall "wants") v.wantedBy
            ++ map (mkInstall "requires") v.requiredBy
            ++ map (mkInstall "upholds") v.upheldBy
          )}
        '') mapped;
      in
      builtins.concatStringsSep "\n" commands;
  };

  # NIXOS: $out/lib/systemd/system $out/lib/systemd/user
  # HM: $out/share/systemd/user
  # HJEM: $out/lib/systemd/user $out/etc/systemd/user (use $out/lib/systemd/user because its the same as nixos)
  config.install.modules.nixos =
    { config, ... }:
    let
      cfg = top.config.install.getWrapperConfig config;
    in
    {
      systemd.packages = lib.mkIf (cfg.enable && builtins.elem "nixos" cfg.install.systemd) [
        cfg.wrapper
      ];
    };
  config.install.modules.homeManager =
    { config, ... }:
    let
      cfg = top.config.install.getWrapperConfig config;
    in
    {
      systemd.user.packages = lib.mkIf (cfg.enable && builtins.elem "homeManager" cfg.install.systemd) [
        cfg.wrapper
      ];
    };
  config.install.modules.hjem =
    { config, ... }:
    let
      cfg = top.config.install.getWrapperConfig config;
    in
    {
      systemd.packages = lib.mkIf (cfg.enable && builtins.elem "hjem" cfg.install.systemd) [
        cfg.wrapper
      ];
    };
}
