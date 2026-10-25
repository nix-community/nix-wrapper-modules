{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [
    wlib.wrapperModules.mdbook
    wlib.docs.wrapperModuleMdBookStyle
    ./redirects.nix
    ./gen_mod_docs.nix
  ];
  config.mainBook = "nix-wrapper-modules";
  config.books.nix-wrapper-modules = {
    applyWrapperModuleStyles = true;
    book = {
      book = {
        authors = [ "BirdeeHub" ];
        language = "en";
        title = "nix-wrapper-modules";
        description = "Make wrapper derivations with the module system! Use the existing modules, or write your own!";
      };
      output.html.git-repository-url = "https://github.com/nix-community/nix-wrapper-modules";
    };
    summary = [
      {
        data = "title";
        name = "nix-wrapper-modules";
      }
      {
        name = "Intro";
        data = "numbered";
        path = "md/intro.md";
        src = "${placeholder "generated"}/wrappers-lib/intro.md";
        build = ''
          mkdir -p $generated/wrappers-lib
          sed 's|# \[nix-wrapper-modules\](https://nix-community.github.io/nix-wrapper-modules/)|# [nix-wrapper-modules](https://github.com/nix-community/nix-wrapper-modules)|' < '${../../README.md}' > "$generated/wrappers-lib/intro.md"
        '';
      }
      {
        name = "Getting Started";
        data = "numbered";
        path = "md/getting-started.md";
        src = ./md/getting-started.md;
      }
      {
        name = "Lib Functions";
        data = "numbered";
        path = "md/lib-intro.md";
        src = ./md/lib-intro.md;
        subchapters = [
          {
            name = "`wlib`";
            data = "numbered";
            path = "lib/wlib.md";
            src = "${placeholder "generated"}/wrappers-lib/wlib.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "" --description '`wlib` main set documentation' --file '${../../lib/lib.nix}' --prefix "wlib" >> $generated/wrappers-lib/wlib.md
            '';
          }
          {
            name = "`wlib.types`";
            data = "numbered";
            path = "lib/types.md";
            src = "${placeholder "generated"}/wrappers-lib/types.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "types" --description '`wlib.types` set documentation' --file '${../../lib/types.nix}' --prefix "wlib" >> $generated/wrappers-lib/types.md
            '';
          }
          {
            name = "`wlib.dag`";
            data = "numbered";
            path = "lib/dag.md";
            src = "${placeholder "generated"}/wrappers-lib/dag.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "dag" --description '`wlib.dag` set documentation' --file '${../../lib/dag.nix}' --prefix "wlib" >> $generated/wrappers-lib/dag.md
            '';
          }
          {
            name = "`wlib.makeWrapper`";
            data = "numbered";
            path = "lib/makeWrapper.md";
            src = "${placeholder "generated"}/wrappers-lib/makeWrapper.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "makeWrapper" --description '`wlib.makeWrapper` set documentation' --file '${../../lib/makeWrapper/default.nix}' --prefix "wlib" >> $generated/wrappers-lib/makeWrapper.md
            '';
          }
          {
            name = "`wlib.docs`";
            data = "numbered";
            path = "lib/docs.md";
            src = "${placeholder "generated"}/wrappers-lib/docs.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "docs" --description '`wlib.docs` set documentation' --file '${../../lib/docs/default.nix}' --prefix "wlib" >> $generated/wrappers-lib/docs.md
            '';
          }
        ];
      }
      {
        name = "Core Options Set";
        data = "numbered";
        path = "lib/core.md";
        src = "${placeholder "generated"}/core.md";
      }
      {
        name = "`wlib.modules.default`";
        data = "numbered";
        path = "modules/default.md";
        src = "${placeholder "generated"}/module_docs/default.md";
      }
      {
        name = "Helper Modules";
        data = "numbered";
        path = "md/helper-modules.md";
        src = ./md/helper-modules.md;
        subchapters = lib.pipe config.drv.module_docs [
          (v: removeAttrs v [ "default" ])
          builtins.attrNames
          (map (n: {
            name = n;
            data = "numbered";
            path = "modules/${n}.md";
            src = "${placeholder "generated"}/module_docs/${n}.md";
          }))
        ];
      }
      {
        name = "Wrapper Modules";
        data = "numbered";
        path = "md/wrapper-modules.md";
        src = ./md/wrapper-modules.md;
        subchapters = map (n: {
          name = n;
          data = "numbered";
          path = "wrapperModules/${n}.md";
          src = "${placeholder "generated"}/wrapper_docs/${n}.md";
        }) (builtins.attrNames config.drv.wrapper_docs);
      }
      {
        name = "Contributing";
        data = "numbered";
        path = "md/CONTRIBUTING.md";
        src = ../../CONTRIBUTING.md;
        subchapters = [
          {
            name = "tlib";
            data = "numbered";
            path = "tlib.md";
            src = "${placeholder "generated"}/wrappers-lib/tlib.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "" --description 'Testing library `tlib` documentation' --file '${../test-lib.nix}' --prefix "tlib" >> $generated/wrappers-lib/tlib.md
            '';
          }
        ];
      }
    ];
  };
}
