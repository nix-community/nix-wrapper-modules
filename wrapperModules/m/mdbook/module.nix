{
  config,
  lib,
  wlib,
  pkgs,
  ...
}@top:
let
  summaryType = lib.types.listOf (
    wlib.types.spec {
      options.data = lib.mkOption {
        type = lib.types.enum [
          "prefix"
          "suffix"
          "title"
          "numbered"
          "draft"
          "separator"
        ];
        description = ''
          Identifies the kind of summary item.

          This determines how the item is rendered in SUMMARY.md and which additional fields are required or meaningful.

          Valid values are:

          title — A section heading in the summary.

          separator — A horizontal rule (---) separating sections. (can be defined simply as the string "separator" in the list unless you want to sort on them)

          prefix — A link rendered before the main numbered chapters.

          suffix — A link rendered after the main numbered chapters.

          numbered — A standard numbered chapter entry.

          draft — A chapter entry without a target path.

          Rendering behavior and required fields depend on this value.
        '';
      };
      options.before = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Ensure this item appears before the named entries in this list
        '';
      };
      options.after = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Ensure this item appears after the named entries in this list
        '';
      };
      options.name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The name of the summary item. Usually rendered as the text of the item.

          Can also be used as a sorting target by `before` and `after` fields of other items.
        '';
      };
      options.subchapters = lib.mkOption {
        type = summaryType;
        default = [ ];
        visible = "shallow";
        description = ''
          The same options as this level of the summary,
          however the items within will be indented 1 level further.
        '';
      };
      options.path = lib.mkOption {
        type = lib.types.nullOr wlib.types.nonEmptyLine;
        default = null;
        description = ''
          The relative output path of the item within the book directory.
        '';
      };
      options.src = lib.mkOption {
        type = lib.types.nullOr wlib.types.stringable;
        default = null;
        description = ''
          If this item is of a type which accepts a source file,
          this file will be linked to the location indicated by the `path` option.
        '';
      };
      options.build = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          If extra processing is required to generate a source file for this item,
          you may specify extra commands to run before the wrapper links it into place here.
        '';
      };
    }
  );

  renderBook =
    bookSrc: summary: bookName:
    let
      renderItemSummary =
        node:
        assert
          (node.depth or null != null) || throw "Type error: node must have depth given by sortBook function";
        let
          i = wlib.repeatStr "  " node.depth;
        in
        if node.data == "title" then
          assert (node.name != null) || throw "Type error: title node must have name";
          ''
            # ${toString node.name}
          ''
        else if node.data == "separator" then
          ''
            ---
          ''
        else if node.data == "prefix" || node.data == "suffix" then
          assert
            (node.name != null && node.path != null)
            || throw "Type error: prefix/suffix node must have name, and path";
          ''
            [${toString node.name}](${toString node.path})
          ''
        else if node.data == "draft" then
          assert (node.name != null) || throw "Type error: draft node must have name";
          ''
            ${i}- [${toString node.name}]()
          ''
        else if node.data == "numbered" then
          assert
            (node.name != null && node.path != null)
            || throw "Type error: numbered node must have name, and path";
          ''
            ${i}- [${toString node.name}](${toString node.path})
          ''
        else
          throw "Unknown summary type: ${node.data}";

      sortBook =
        let
          recsort =
            depth:
            lib.flip lib.pipe [
              (wlib.dag.unwrapSort "mdbook")
              (builtins.concatMap (
                v:
                [
                  (
                    v
                    // {
                      inherit depth;
                      subchapters = [ ];
                    }
                  )
                ]
                ++ recsort (depth + 1) (v.subchapters or [ ])
              ))
            ];
        in
        recsort 0;

      mkLink =
        node:
        if node.src != null && node.path != null then
          let
            p = lib.escapeShellArg "${bookSrc}/${lib.removePrefix "/" node.path}";
          in
          ''
            mkdir -p "$(dirname ${p})"
            ${node.build}
            ln -s ${lib.escapeShellArg node.src} ${lib.escapeShellArg "${bookSrc}/${lib.removePrefix "/" node.path}"}
          ''
        else
          "";
      sortedBook = sortBook summary;
    in
    {
      summaryMD = builtins.concatStringsSep "\n" (
        map (
          v:
          builtins.addErrorContext "while rendering summary item from book `${bookName}`: `${builtins.toJSON v}`" (
            renderItemSummary v
          )
        ) sortedBook
      );
      linkCmds = builtins.concatStringsSep "\n" (map mkLink sortedBook);
    };

  tomltype = wlib.types.structuredValueWith { typeName = "nullable TOML"; };

  book-out-dir = "${top.config.binName}-book-dir";
in
{
  imports = [ wlib.modules.default ];
  options = {
    book-out-dir = lib.mkOption {
      readOnly = true;
      type = lib.types.str;
      default = book-out-dir;
      description = ''
        The books are generated to:

        `''${placeholder config.outputName}/''${config.book-out-dir}/''${name}`
      '';
    };
    books = lib.mkOption {
      description = ''
        A set of books to generate along with the mdbook derivation.

        It will also create a build script for each one.

        That build script will be a wrapped mdbook executable.

        It will run something like the following:

        `mdbook build -d $firstArg "''${otherArgs[@]}" <generated-book-subdir>`

        You could modify it further with the `wrapperVariants` attribute of the same name,
        for example to add a `-o` flag.

        Or use it as the main command for running via `nix run` in a build pipeline using `mainBook = "this_book";`
      '';
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              book = lib.mkOption {
                default = { };
                description = ''
                  Values for the `book.toml` file for this book.

                  Reference: [rust-lang.github.io/mdBook/format/configuration/general.html](https://rust-lang.github.io/mdBook/format/configuration/general.html)

                  Any `null` values will be as if not declared.
                '';
                type = lib.types.submodule {
                  freeformType = tomltype;
                  options.book = lib.mkOption {
                    description = ''
                      The `book` table of the `book.toml` file.

                      Reference: [rust-lang.github.io/mdBook/format/configuration/general.html#general-metadata](https://rust-lang.github.io/mdBook/format/configuration/general.html#general-metadata)
                    '';
                    type = lib.types.submodule {
                      freeformType = tomltype;
                      options.src = lib.mkOption {
                        type = lib.types.nonEmptyStr;
                        default = "src";
                        description = ''
                          By default, the source directory is found in the directory named src directly under the root folder.
                        '';
                      };
                      options.title = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = ''
                          The title of the book
                        '';
                      };
                      options.authors = lib.mkOption {
                        type = lib.types.nullOr (lib.types.listOf lib.types.str);
                        default = null;
                        description = ''
                          The author(s) of the book
                        '';
                      };
                      options.description = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = ''
                          A description for the book, which is added as meta information in the html `<head>` of each page
                        '';
                      };
                      options.language = lib.mkOption {
                        type = lib.types.nullOr lib.types.nonEmptyStr;
                        default = null;
                        description = ''
                          The main language of the book, which is used as a
                          language attribute `<html lang="en">` for example.
                          This is also used to derive the direction of text (RTL, LTR) within the book.
                        '';
                      };
                      options.text-direction = lib.mkOption {
                        type = lib.types.nullOr lib.types.nonEmptyStr;
                        default = null;
                        description = ''
                          The direction of text in the book: Left-to-right (LTR) or Right-to-left (RTL).

                          Possible values: `ltr`, `rtl`.

                          When not specified, the text direction is derived from the book’s language attribute.
                        '';
                      };
                    };
                  };
                };
              };
              enable = lib.mkEnableOption "the book `${name}`" // {
                default = true;
              };
              summary = lib.mkOption {
                type = summaryType;
                default = [ ];
                description = ''
                  Builds your summary, and your book!

                  A list of specs, with the main field, `data`,
                  representing the type of the item.

                  Accepts `prefix`, `suffix`, `title`, `numbered`, `draft`, `separator`

                  For info on what those are:

                  [rust-lang.github.io/mdBook/format/summary](https://rust-lang.github.io/mdBook/format/summary.html)

                  In addition, it accepts `name`, `subchapters`, `src`, and `path`.

                  These values are processed differently depending on the type of item.

                  `path` refers to the output path `src` will be linked to.

                  It is relative to the book root dir.

                  `name` is the visible part of the summary item, if it displays text.

                  You can also sort based on `name`, `before`, and `after` like the other DAL options.

                  It will sort within each chapter list if any orderings were specified.

                  `subchapters` are processed recursively, and the depth represents the indentation of the summary item.
                '';
              };
              defaultOutLocation = lib.mkOption {
                type = lib.types.str;
                default = "_site";
                description = ''
                  The book outputs take the target directory to generate to as their first argument.

                  This sets the default output directory for this book if the first argument is not supplied.
                '';
              };
              generated-book-subdir = lib.mkOption {
                type = lib.types.str;
                readOnly = true;
                default = "${book-out-dir}/${name}";
                description = ''
                  The directory within the wrapped derivation that contains the generated markdown for the book.

                  `''${placeholder config.outputName}/''${config.books.<name>.generated-book-subdir}` is the root of this book.
                '';
              };
            };
          }
        )
      );
    };
    mainBook = lib.mkOption {
      type = lib.types.nullOr wlib.types.nonEmptyLine;
      default = null;
      description = ''
        If not null, replace the main package with a link to the generator script for that book
      '';
    };
    buildCommand = lib.mkOption {
      type = lib.types.attrsOf (
        wlib.types.spec {
          config.before = [ "mkMdBooks" ];
        }
      );
    };
  };

  config = {
    wrapperVariants = builtins.mapAttrs (_: v: {
      config.appendFlag = [
        {
          data = "${placeholder config.outputName}/${v.generated-book-subdir}";
          name = "GENERATED_MD_BOOK";
        }
      ];
      options.appendFlag = lib.mkOption {
        type = lib.types.listOf (
          wlib.types.spec {
            before = lib.mkDefault [ "GENERATED_MD_BOOK" ];
          }
        );
      };
      options.addFlag = lib.mkOption {
        type = lib.types.listOf (
          wlib.types.spec {
            after = lib.mkDefault [ "build" ];
          }
        );
      };
      options.flags = lib.mkOption {
        type = lib.types.attrsOf (
          wlib.types.spec {
            after = lib.mkDefault [ "build" ];
          }
        );
      };
      options.runShell = lib.mkOption {
        type = lib.types.listOf (
          wlib.types.spec {
            after = lib.mkDefault [ "PROCESS_ARG_1" ];
          }
        );
      };
      config.enable = v.enable;
      config.flags.build = true;
      config.runShell = [
        {
          name = "PROCESS_ARG_1";
          data = "doc_out=\${1:-${v.defaultOutLocation}}; shift 1";
        }
      ];
      config.flags."-d" = {
        data = "\"$doc_out\"";
        esc-fn = v: v;
      };
      config.exePath = config.exePath;
    }) config.books;
    drv = {
      __structuredAttrs = true;
      nativeBuildInputs = [
        pkgs.remarshal
        pkgs.jq
      ];
      bookData = lib.pipe config.books [
        (lib.filterAttrs (n: v: v.enable or false == true))
        (builtins.mapAttrs (
          n: v:
          let
            src = "${placeholder config.outputName}/${v.generated-book-subdir}/${
              lib.removePrefix "/" (lib.removeSuffix "/" (v.book.book.src or "src"))
            }";
            pages = renderBook src v.summary n;
          in
          {
            summary = pages.summaryMD;
            book = builtins.toJSON (
              lib.filterAttrsRecursive (_: v: !builtins.isFunction v && v != null) v.book
            );
            root = "${placeholder config.outputName}/${v.generated-book-subdir}";
            inherit src;
            build = pages.linkCmds;
          }
        ))
      ];
    };
    buildCommand.mkMdBooks = ''
      jq -r '.bookData | values[] | @base64' "$NIX_ATTRS_JSON_FILE" |
      while read -r entry; do
        value="$(printf '%s' "$entry" | base64 --decode)"
        book_src="$(printf '%s' "$value" | jq -r '.src')"
        book_root="$(printf '%s' "$value" | jq -r '.root')"

        # this is the innermost dir this section handles
        mkdir -p "$book_src"

        # generate summary
        printf '%s' "$value" | jq -r '.summary' > "$book_src/SUMMARY.md"

        # generate book.toml
        printf '%s' "$value" | jq -r '.book' | json2toml > "$book_root/book.toml"

        # generate book contents
        eval "$(printf '%s' "$value" | jq -r '.build')"
      done
    ''
    +
      lib.optionalString
        (
          config.mainBook != null
          && config.wrapperVariants."${config.mainBook}".enable or false == true
          && config.books."${config.mainBook}".enable or false == true
        )
        ''
          ln -sf ${config.mainBook} ${config.wrapperPaths.placeholder}
        '';
    passthru.book-out-dir = book-out-dir;
    package = lib.mkDefault pkgs.mdbook;
    meta.maintainers = [ wlib.maintainers.birdee ];
    meta.description = ''
      This module makes use of `wrapperVariants` to make a script for each of the books you define.

      If you make an entry in the `books` attribute set, you will get a binary of that name,
      which as its first argument takes the output directory to generate to (or a default if not provided).

      As each one already has its book directory specified and `-d` option set to the first argument or a default,
      you only have access to the other flags on these items at runtime.

      To achieve greater runtime control, run the main executable with one of the generated books within the derivation
      as input yourself, either at runtime, or within the module via `''${placeholder config.outputName}/''${config.book-out-dir}/''${name}`

      Within the module, there is an option called `mainBook` to REPLACE the main executable with a symlink to the desired book generation script.

      For more fine-tuned control, you should instead give it the path to the book yourself as demonstrated above.
    '';
  };
}
