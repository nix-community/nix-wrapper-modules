{
  config,
  wlib,
  buildCommand,
  # other args from callPackage
  lib,
  lndir,
  stdenv,
  luajitPackages,
  luajit,
  ...
}:
finalDrv:
let
  final-packdir = "${placeholder outputName}/${binName}-packdir";
  start-dir = "${final-packdir}/pack/myNeovimPackages/start";
  opt-dir = "${final-packdir}/pack/myNeovimPackages/opt";
  info-plugin-path = "${start-dir}/${config.settings.info_plugin_name}";

  inherit (config)
    package
    binName
    outputs
    outputName
    wrapperPaths
    ;
  inherit (config.settings) info_plugin_name dont_link aliases;
  originalOutputs = wlib.getPackageOutputsSet package;
  manifestLua =
    (finalDrv.manifestLua or "")
    + "\n"
    + ''
      vim.opt.packpath:prepend(${builtins.toJSON final-packdir})
      vim.opt.runtimepath:prepend(${builtins.toJSON final-packdir})
      vim.g.nix_info_plugin_name = ${builtins.toJSON info_plugin_name}
      local configdir
      ${lib.optionalString config.settings.block_normal_config ''
        configdir = vim.fn.stdpath("config")
        vim.opt.packpath:remove(configdir)
        vim.opt.runtimepath:remove(configdir)
        vim.opt.runtimepath:remove(configdir .. "/after")
      ''}
    '';
  maybe_compile = "${lib.optionalString (config.settings.compile_generated_lua or false != false)
    "| ${config.package.lua or luajit}/bin/lua -e 'local src=io.read([[*a]]); local f,err=load(src); if not f then error(err) end; io.write(string.dump(f${
      lib.optionalString (config.settings.compile_generated_lua or false != "debug") ", true"
    }))' "
  }";
  patchDesktop = input: output: ''
    if [ -e "${package}/share/applications/${input}.desktop" ]; then
      mkdir -p '${placeholder outputName}/share/applications'
      rm -f '${placeholder outputName}/share/applications/${input}.desktop'
      substitute ${
        lib.escapeShellArgs [
          "${package}/share/applications/${input}.desktop"
          "${placeholder outputName}/share/applications/${output}.desktop"
          "--replace-fail"
          "Name=Neovim"
          "Name=${binName}"
          "--replace-fail"
          "TryExec=nvim"
          "TryExec=${wrapperPaths.placeholder}"
          "--replace-fail"
          "Icon=nvim"
          "Icon=${package}/share/icons/hicolor/128x128/apps/nvim.png"
        ]
      }
      sed ${
        lib.escapeShellArgs [
          ''
            /^Exec=nvim/c\
            Exec=${wrapperPaths.placeholder} %F''
          "${placeholder outputName}/share/applications/${output}.desktop"
        ]
      } > ./tmp_desk && mv -f ./tmp_desk "${placeholder outputName}/share/applications/${output}.desktop"
    fi
  '';
in
finalDrv
// {
  outputs = if dont_link then [ outputName ] else outputs;
  passAsFile = [
    "manifestLua"
    "setupLua"
    "infoPluginText"
    "infoPluginInitMain"
    "buildPackDir"
    "hostLinkCmd"
    "buildCommand"
  ]
  ++ finalDrv.passAsFile or [ ];
  inherit manifestLua;
  setupLua = ''
    if package.preload[ ${builtins.toJSON info_plugin_name} ] then return end
    ${manifestLua}
    package.preload[ ${builtins.toJSON info_plugin_name} ] = function()
      return dofile(${builtins.toJSON "${info-plugin-path}/lua/${info_plugin_name}.lua"})
    end
    package.preload[ ${builtins.toJSON "${config.settings.info_plugin_name}.init_main"} ] = function()
      return dofile(${builtins.toJSON "${info-plugin-path}/lua/${info_plugin_name}/init_main.lua"})
    end
    configdir = require(${builtins.toJSON info_plugin_name}).settings.config_directory
    vim.opt.packpath:prepend(configdir)
    vim.opt.runtimepath:prepend(configdir)
    vim.opt.runtimepath:append(configdir .. "/after")
  '';
  buildCommand = ''
    mkdir -p ${placeholder outputName}/bin
    [ -d ${package}/nix-support ] && \
    mkdir -p ${placeholder outputName}/nix-support && \
    cp -r ${package}/nix-support/* ${placeholder outputName}/nix-support

  ''
  + ''

    # Create symlinks for aliases
    ${lib.optionalString (aliases != [ ] && binName != "") ''
      mkdir -p '${placeholder outputName}/bin'
      for alias in ${lib.concatStringsSep " " (map lib.escapeShellArg aliases)}; do
        ln -sf ${wrapperPaths.placeholder} ${placeholder outputName}/bin/$alias
      done
    ''}

    [ -e "$hostLinkCmdPath" ] && . "$hostLinkCmdPath" || runHook hostLinkCmd
    mkdir -p ${lib.escapeShellArg "${info-plugin-path}/lua/${info_plugin_name}"}
    mkdir -p ${lib.escapeShellArg opt-dir}
    [ -e "$buildPackDirPath" ] && . "$buildPackDirPath" || runHook buildPackDir
    {
      [ -e "$infoPluginTextPath" ] && cat "$infoPluginTextPath" || echo "$infoPluginText";
    } ${maybe_compile}> ${lib.escapeShellArg "${info-plugin-path}/lua/${info_plugin_name}.lua"}
    {
      [ -e "$infoPluginInitMainPath" ] && cat "$infoPluginInitMainPath" || echo "$infoPluginInitMain";
    } ${
      lib.optionalString (finalDrv.hasFennel or false)
        "| ${config.package.lua.pkgs.fennel or luajitPackages.fennel}/bin/fennel --compile - "
    }${maybe_compile}> ${lib.escapeShellArg "${info-plugin-path}/lua/${info_plugin_name}/init_main.lua"}
    mkdir -p ${lib.escapeShellArg "${final-packdir}/nix-support"}
    for i in $(find -L ${lib.escapeShellArg final-packdir} -name propagated-build-inputs ); do
      cat "$i" >> ${lib.escapeShellArg "${final-packdir}/nix-support/propagated-build-inputs"}
    done

    # see:
    # https://github.com/NixOS/nixpkgs/issues/318925
    echo "Looking for lua dependencies..."
    source ${config.package.lua}/nix-support/utils.sh || true
    _addToLuaPath ${lib.escapeShellArg final-packdir} || true
    echo "propagated dependency path for plugins: $LUA_PATH"
    echo "propagated dependency cpath for plugins: $LUA_CPATH"
  ''
  + "\n"
  + buildCommand
  + "\n"
  + lib.optionalString (!dont_link) ''

    # Handle additional outputs by symlinking from the original package's outputs
    ${lib.concatMapStringsSep "\n" (
      output:
      if originalOutputs ? ${output} && originalOutputs.${output} != null then
        ''
          if [[ -n "''${${output}:-}" ]]; then
            mkdir -p ${placeholder output}
            # Only symlink from the original package's corresponding output
            ${lndir}/bin/lndir -silent "${originalOutputs.${output}}" ${placeholder output}
          fi
        ''
      else
        ""
    ) outputs}

  ''
  + lib.optionalString stdenv.hostPlatform.isLinux (
    patchDesktop "nvim" binName + patchDesktop "org.neovim.nvim" "org.neovim.${binName}"
  );
}
