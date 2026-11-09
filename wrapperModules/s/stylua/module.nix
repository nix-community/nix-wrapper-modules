{
  wlib,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    customStyle = lib.mkOption {
      type = wlib.types.structuredValueWith {
        nullable = false;
        typeName = "TOML";
      };
      default = { };
      description = ''
        nix configuration for the stylua.

        Check [StyLua options](https://github.com/JohnnyMorganz/StyLua/blob/main/README.md#options).
      '';
      example = lib.literalExpression ''
        settings = {
          call_parentheses = "Always";
          column_width = 100;
          collapse_simple_statement = "Always";
          indent_type = "Spaces";
          indent_width = 2;
          quote_style = "ForceDouble";
          sort_requires.enabled = true;
        };
      '';
    };
    generateCpScript = lib.mkOption {
      default = { };
      description = ''
        Options for copy script which help you quickly copy your
        settings into `$CWD` for further customization.

        The script's name can be customized.
      '';
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption ''
            generating a copy script.

            If you don't add `customStyle`, the script will instead exit with a warning.
          '';
          name = lib.mkOption {
            type = lib.types.str;
            default = "cp_stylua_toml";
            description = ''
              Customize the name of the copy script. If the name has `/` in it,
              the wrapper will ignore and only take the base name.
            '';
          };
        };
      };
    };
  };
  config = {
    package = lib.mkDefault pkgs.stylua;
    constructFiles.generatedConfig = lib.mkIf (config.customStyle != { }) {
      content = builtins.toJSON config.customStyle;
      relPath = "styles/stylua.toml";
      builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };
    constructFiles."${baseNameOf config.generateCpScript.name}" =
      lib.mkIf config.generateCpScript.enable
        {
          relPath = "bin/${baseNameOf config.generateCpScript.name}";
          builder = "cp $1 $2 && chmod +x $2";
          content = ''
            #!${pkgs.bash}${pkgs.bash.shellPath}
            help=$'cp_stylua_toml [-h|--help] [-f] [-p] <DIR>\nCopy generated stylua.toml to a target directory (defaults to the current directory).\n\nOptions:\n\t-f  :  Overwrite the target destination if it exists\n\t-p  :  Create target directory if it does not exist'

            source=${
              placeholder config.constructFiles.generatedConfig.output or config.outputName
            }/styles/stylua.toml
            dir=$(pwd)
            force=0
            mkdirp=0

            while [ "$#" -gt 0 ]; do
              case "$1" in
                -h|--help)
                  echo "$help"
                  exit 0
                  ;;
                -f)
                  force=1
                  ;;
                -p)
                  mkdirp=1
                  ;;
                -pf|-fp)
                  mkdirp=1
                  force=1
                  ;;
                *)
                  dir="$1"
                  break
                  ;;
              esac
              shift
            done

            [ ! -e "$source" ] \
            && echo "The associated wrapper module for this wrapped stylua binary does not define any stylua.toml configuration." \
            && exit 0

            target="$dir/stylua.toml"

            if [ "$mkdirp" -eq 1 ]; then
              mkdir -p "$dir" || { echo "failed to create directory $dir! exiting..." >&2; exit 1; };
            elif [ ! -d "$dir" ]; then
              echo "Target directory '$dir' does not exist. Use -p to create it."
              exit 1
            fi

            if [ -e "$target" ] && [ "$force" -ne 1 ]; then
              echo "$target already exists. Use -f to overwrite it."
              exit 1
            fi

            touch "$target"
            cat "$source" > "$target"
          '';
        };
    flags."--config-path" = lib.mkIf (
      config.customStyle != { }
    ) config.constructFiles.generatedConfig.path;
    meta = {
      maintainers = with wlib.maintainers; [
        kuppo
      ];
      description = ''
        Wrapper Module for [Stylua](https://github.com/JohnnyMorganz/StyLua).

        The wrapper is used to customize the `stylua.toml` file.
        You can add you options into `config.customStyle` with pure nix expressions.

        The wrapper also provides a script which copys the generated `stylua.toml`
        into `$CWD`, in case you want to include the confitugation into the repo or
        customize it somehow.
      '';
    };
  };
}
