{
  config,
  wlib,
  lib,
  ...
}:
let
  desc = ''

    This will add javascript file to the book which will make wrapper module documentation look better.

    The first thing it does is add dropdown arrows to the sidebar,
    which allow subchapters to be expanded and collapsed.

    In addition, for every markdown page given to mdbook containing the following line:

    `<div nix-wrapper-module-documentation-style-tag hidden></div>`

    It will provide further CSS styling for indentation and details expansion elements,
    and sync the expansion of elements on the page to the sidebar.

    Github already renders the dropdown arrows for the summary headings in line with the headings,
    so this css is unnecessary if viewing the generated markdown directly there.
  '';
in
{
  meta.maintainers = [ wlib.maintainers.birdee ];
  meta.description = ''
    This module is an extension to the mdbook wrapper module.

    It adds a boolean `applyWrapperModuleStyles` option to each book in the books set.

    Import this module in your mdbook wrapper module, and then set `config.books.<your_book_name>.applyWrapperModuleStyles = true;`
  ''
  + desc;
  options.books = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }: {
          options.applyWrapperModuleStyles = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Apply the wrapper module documentation style fixes to this book.
            ''
            + desc;
          };
          config.book.output.html.additional-js = lib.mkIf config.applyWrapperModuleStyles [
            "nix_wrapper_modules_styles.js"
          ];
        }
      )
    );
  };
  config.buildCommand.applyWrapperModuleStyles = {
    after = [
      "constructFiles"
      "makeWrapper"
      "symlinkScript"
    ];
    data = lib.pipe config.books [
      (lib.filterAttrs (n: v: v.applyWrapperModuleStyles))
      builtins.attrNames
      (map (n: ''
        mkdir -p ${lib.escapeShellArg "${placeholder config.outputName}/${config.books.${n}.generated-book-subdir}"}
        cp ${lib.escapeShellArg ./wrapper-module-mdbook-style.js} ${lib.escapeShellArg "${placeholder config.outputName}/${config.books.${n}.generated-book-subdir}/nix_wrapper_modules_styles.js"}
      ''))
      (builtins.concatStringsSep "\n")
    ];
  };
}
