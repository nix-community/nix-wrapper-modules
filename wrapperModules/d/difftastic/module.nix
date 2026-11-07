{
  lib,
  wlib,
  pkgs,
  config,
  ...
}:
let
  mkEnvVarName = name: "DFT_${lib.replaceString "-" "_" (lib.toUpper name)}";

  mkEnvVarValue =
    value:
    if builtins.isString value then
      value
    else if builtins.isInt value then
      toString value
    else if builtins.isBool value then
      lib.boolToString value
    else
      throw "Unrecognized type ${builtins.typeOf value} in difftastic settings";

  # converts single-attribute attrset to a string
  mkOverrideValue = lib.attrsets.foldlAttrs (
    _: name: value:
    "${name}:${value}"
  ) "";

  settingsToEnv = lib.pipe config.settings [
    (lib.filterAttrs (_: value: value != null)) # settings with null values do not need to be handled
    (lib.filterAttrs (name: _: !lib.hasPrefix "override" name)) # override* settings need special handling
    (lib.mapAttrs' (name: value: lib.nameValuePair (mkEnvVarName name) (mkEnvVarValue value)))
  ];
in
{
  imports = [ wlib.modules.default ];
  options.settings = {
    background = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "dark"
          "light"
        ]
      );
      default = null;
      description = ''
        Set the background brightness.
        Difftastic will prefer brighter colours on dark backgrounds.
      '';
    };
    byte-limit = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        Use a line-oriented diff if either input file exceeds this size (in bytes).
      '';
    };
    check-only = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Report whether there are any changes, but don't calculate them. Much faster.
      '';
    };
    color = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "always"
          "auto"
          "never"
        ]
      );
      default = null;
      description = ''
        When to use color output: always, auto, never.
      '';
    };
    context = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        The number of contextual lines to show around changed lines.
      '';
    };
    display = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "side-by-side"
          "side-by-side-show-both"
          "inline"
          "json"
        ]
      );
      default = null;
      description = ''
        Display mode for showing results.

        side-by-side: Display the before file and the after file in two separate columns,
                      with line numbers aligned according to unchanged content.
                      If a change is exclusively additions or exclusively removals,
                      use a single column.

        side-by-side-show-both: The same as side-by-side, but always uses two columns.

        inline: A single column display, closer to traditional diff display.

        json: Output the results as a machine-readable JSON array with an element per file."
      '';
    };
    exit-code = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Set the exit code to 1 if there are syntactic changes in any files.
        For files where there is no detected language (e.g. unsupported language or binary files),
        sets the exit code if there are any byte changes.
      '';
    };
    graph-limit = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        Use a line-oriented diff if the structural graph exceed this number of nodes in memory.
      '';
    };
    ignore-comments = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Don't consider comments when diffing.
      '';
    };
    override = lib.mkOption {
      # Order for this option is important but uting just plaintext list doesn't look good nor
      # efficient thus this type
      type = lib.types.attrListOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''
        lib.mkMerge [
          {
            "*.data" = lib.mkAfter "text";
            "*.c" = lib.mkBefore "C++";
          };
          [
            { "*.js" = "javascript jsx" }
            { "CustomFile" = "json" };
          ]
        ]'';
      description = ''
        Associate this glob pattern with this language, overriding normal language detection.

        See `difft --list-languages` for the list of language names. Language names are matched
        case insensitively. Overrides may also specify the language "text" to treat a file
        as plain text.

        When multiple overrides are specified, the first matching override wins.

        Value of this option can be either list of single-attribute attrSets,
        or attribute set with values wrapped in lib.mkOrder (or lib.mkBefore/lib.mkAfter)
        to control orediring.
        Use lib.mkMerge or imports to use mixed formats at one place.
      '';
    };
    override-binary = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''
        [
                "*.gz"
                "foo.pickle"
                "*.data"
              ]'';
      description = ''
        Always treat file names matching this glob as binary files,
        ignoring the default heuristics for binary detection.
      '';
    };
    parse-error-limit = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        Use a line-oriented diff if the number of parse errors exceeds this value.
      '';
    };
    skip-unchanged = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Don't display anything if a file is unchanged.
      '';
    };
    sort-paths = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        When diffing a directory, output the results sorted by path. This is slower.
      '';
    };
    strip-cr = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "on"
          "off"
        ]
      );
      default = null;
      description = ''
        Remove any carriage return characters before diffing.
        This can be helpful when dealing with files on Windows that contain CRLF, i.e. `\r\n.`
      '';
    };
    syntax-highlight = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "on"
          "off"
        ]
      );
      default = null;
      description = ''
        Enable or disable syntax highlighting.
      '';
    };
    tab-width = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        Treat a tab as this many spaces.
      '';
    };
    width = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        Use this many columns when calculating line wrapping.
        If not specified (default), difftastic will detect the terminal width.
      '';
    };
    min-width = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      description = ''
        Custom option to prevent difftastic (in runtime) to set width lower then
        the given number of columns.
        Takes effect only when settings.width isn't set but still allow overriding
        width by cli flag and/or env variable passed outside the wrapper settings.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.difftastic;
    envDefault = settingsToEnv;
    flags."--override" = {
      ifs = null;
      sep = "=";
      data = map mkOverrideValue config.settings.override;
    };
    flags."--override-binary" = {
      ifs = null;
      sep = "=";
      data = config.settings.override-binary;
    };

    # min-width is need to be calculated in runtime
    runShell = lib.mkIf (config.settings.min-width != null && config.settings.width == null) [
      /* bash */ ''
        POSITIONAL=()
        while [[ $# -gt 0 ]]; do
          key="$1"
          case $key in
            --width=*) WIDTH="$(echo "$1" | cut -d'=' -f2)"; shift;;
            -w|--width) WIDTH="$2"; shift; shift ;;
            *) POSITIONAL+=("$1"); shift ;;
          esac
        done
        set -- "''${POSITIONAL[@]}"
        WIDTH="''${WIDTH:-"$(stty size | cut -d' ' -f2)"}"

        [[ "$WIDTH" -lt "${toString config.settings.min-width}" ]] &&
          wrapperSetEnvDefault DFT_WIDTH ${toString config.settings.min-width}
      ''
    ];

    meta.maintainers = [ wlib.maintainers.alexlov ];
  };
}
