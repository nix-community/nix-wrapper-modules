{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  inherit (import ./per-mod { inherit lib wlib; }) wrapperModuleMD;
  buildModuleDocs =
    {
      prefix ? "",
      title ? null,
      package ? null,
      includeCore ? true,
      descriptionStartsOpen ? null,
      descriptionIncluded ? null,
      moduleStartsOpen ? null,
      warningsAreErrors ? true,
    }:
    name: module:
    (if title != null then "# ${title}\n\n" else "# `${prefix}${name}`\n\n")
    + wrapperModuleMD (
      wlib.evalModule [
        module
        {
          _module.check = false;
          inherit pkgs;
          ${if package != null then "package" else null} = package;
        }
      ]
      // {
        inherit includeCore warningsAreErrors;
        ${if descriptionStartsOpen != null then "descriptionStartsOpen" else null} = descriptionStartsOpen;
        ${if descriptionIncluded != null then "descriptionIncluded" else null} = descriptionIncluded;
        ${if moduleStartsOpen != null then "moduleStartsOpen" else null} = moduleStartsOpen;
      }
    );

in
{
  imports = [
    wlib.wrapperModules.mdbook
    ./redirects.nix
  ];
  config.mainBook = "nix-wrapper-modules";
  config.outputs = [
    "out"
    "generated"
  ];
  options.warningsAreErrors = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether warnings in the docgen should be treated as errors (i.e. missing descriptions)";
  };
  config.drv.unsafeDiscardReferences.generated = true;
  config.drv.preBuild = ''
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
  '';
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
  config.constructFiles."custom.css" = {
    relPath = "${config.books.nix-wrapper-modules.generated-book-subdir}/custom.css";
    passAsContent = true;
    content = /* css */ ''
      /* Set headings to display next to the details element dropdown */
      summary > h1, summary > h2, summary > h3 {
        display: inline;
      }
      /* Indent module subsections (they are details elements in the module's details element) */
      details > details{
        padding-left: 20px;
      }
    '';
  };
  config.constructFiles."sidebar_fold.js" = {
    relPath = "${config.books.nix-wrapper-modules.generated-book-subdir}/sidebar_fold.js";
    passAsContent = true;
    content = /* js */ ''

      (function () {

        // Sets the sidebar sections open/closed status to match the open/closed state of the relevant details element
        function updateSidebarFromDetails() {

            // Relies on the fact that module headings are the only level 2 headings in details elements
            const closed_modules = document.querySelectorAll("details:not([open]) h2");
            const open_modules = document.querySelectorAll("details[open] h2");
            if (closed_modules.length === 0 && open_modules === 0) { return; }

            closed_modules.forEach(module_heading => {
                const module_sidebar = document.querySelector(`a[href='#''${module_heading.id}']`);
                module_sidebar.closest("li").classList.remove("expanded");
            });

            open_modules.forEach(module_heading => {
                const module_sidebar = document.querySelector(`a[href='#''${module_heading.id}']`);
                module_sidebar.closest("li").classList.add("expanded");
            });
        }

        const foldable_details = document.querySelectorAll("details:has(h2)");
        foldable_details.forEach(details => {
            details.addEventListener("toggle", () => { updateSidebarFromDetails(); });
        });

        // mdbook js loads toc elements on DOMContentLoaded so we have to use window 'load' here
        window.addEventListener("load", function () {
            updateSidebarFromDetails();

            // Add dropdown arrows to the sidebar, using the existing functionality from mdbook's toc.js
            const foldable_sidebar = document.querySelectorAll("span:has(+ ol)");
            foldable_sidebar.forEach(header => {
              header.insertAdjacentHTML('beforeend', '<a class="chapter-fold-toggle header-toggle"><div>❱</div></a>');
              header.querySelector("a.header-toggle").addEventListener("click", () => {
                header.closest("li").classList.toggle("expanded");
                });
            });
        });
      })();
    '';
  };
  config.books.nix-wrapper-modules = {
    book = {
      book = {
        src = "src";
        authors = [ "BirdeeHub" ];
        language = "en";
        title = "nix-wrapper-modules";
        description = "Make wrapper derivations with the module system! Use the existing modules, or write your own!";
      };
      output.html = {
        git-repository-url = "https://github.com/nix-community/nix-wrapper-modules";
        additional-css = [ "custom.css" ];
        additional-js = [ "sidebar_fold.js" ];
      };
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
        src = "${placeholder "out"}/wrappers-lib/intro.md";
        build = ''
          mkdir -p $out/wrappers-lib
          sed 's|# \[nix-wrapper-modules\](https://nix-community.github.io/nix-wrapper-modules/)|# [nix-wrapper-modules](https://github.com/nix-community/nix-wrapper-modules)|' < '${../../README.md}' > "$out/wrappers-lib/intro.md"
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
            src = "${placeholder "out"}/wrappers-lib/wlib.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "" --description '`wlib` main set documentation' --file '${../../lib/lib.nix}' --prefix "wlib" >> $out/wrappers-lib/wlib.md
            '';
          }
          {
            name = "`wlib.types`";
            data = "numbered";
            path = "lib/types.md";
            src = "${placeholder "out"}/wrappers-lib/types.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "types" --description '`wlib.types` set documentation' --file '${../../lib/types.nix}' --prefix "wlib" >> $out/wrappers-lib/types.md
            '';
          }
          {
            name = "`wlib.dag`";
            data = "numbered";
            path = "lib/dag.md";
            src = "${placeholder "out"}/wrappers-lib/dag.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "dag" --description '`wlib.dag` set documentation' --file '${../../lib/dag.nix}' --prefix "wlib" >> $out/wrappers-lib/dag.md
            '';
          }
          {
            name = "`wlib.makeWrapper`";
            data = "numbered";
            path = "lib/makeWrapper.md";
            src = "${placeholder "out"}/wrappers-lib/makeWrapper.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "makeWrapper" --description '`wlib.makeWrapper` set documentation' --file '${../../lib/makeWrapper/default.nix}' --prefix "wlib" >> $out/wrappers-lib/makeWrapper.md
            '';
          }
        ];
      }
      {
        name = "Core Options Set";
        data = "numbered";
        path = "lib/core.md";
        build = ''
          jq -r '.core_docs' "$NIX_ATTRS_JSON_FILE" > "$generated/core.md"
        '';
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
            src = "${placeholder "out"}/wrappers-lib/tlib.md";
            build = ''
              ${pkgs.nixdoc}/bin/nixdoc --category "" --description 'Testing library `tlib` documentation' --file '${../test-lib.nix}' --prefix "tlib" >> $out/wrappers-lib/tlib.md
            '';
          }
        ];
      }
    ];
  };
}
