{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;

  jsonFormat = pkgs.formats.json { };

  isPathLike = value: builtins.isPath value || lib.isStorePath value;

  generatedSettings =
    config.userSettings
    // optionalAttrs (config.extensions != [ ]) {
      auto_install_extensions = lib.genAttrs config.extensions (_: true);
    };

  pathThemes = lib.filterAttrs (_name: value: isPathLike value) config.themes;

  generatedThemes = lib.filterAttrs (_name: value: !(isPathLike value)) config.themes;

  hasGeneratedConfig =
    generatedSettings != { }
    || config.userKeymaps != [ ]
    || config.userTasks != [ ]
    || config.userDebug != [ ]
    || config.themes != { };

  generatedZedConfigDir = "${config.generatedConfig.path}/zed";

  mkJsonFile = relPath: value: {
    inherit relPath;
    content = builtins.toJSON value;
  };

  mkThemeFile = name: value: {
    relPath = "${config.generatedConfig.relPath}/zed/themes/${name}.json";
    content = if builtins.isString value then value else builtins.toJSON value;
  };

in
{
  imports = [ wlib.modules.default ];

  options = {
    userSettings = mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = {
        vim_mode = true;
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        ui_font_family = "JetBrainsMono Nerd Font";
        buffer_font_family = "JetBrainsMono Nerd Font";
      };
      description = ''
        Configuration written to Zed's `settings.json`.

        This is equivalent to Home Manager's
        `programs.zed-editor.userSettings` option.
      '';
    };

    userKeymaps = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = [
        {
          context = "Workspace";
          bindings = {
            ctrl-shift-t = "workspace::NewTerminal";
          };
        }
      ];
      description = ''
        Configuration written to Zed's `keymap.json`.

        This is equivalent to Home Manager's
        `programs.zed-editor.userKeymaps` option.
      '';
    };

    userTasks = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = [
        {
          label = "nix flake check";
          command = "nix";
          args = [
            "flake"
            "check"
          ];
        }
      ];
      description = ''
        Configuration written to Zed's `tasks.json`.

        These are global Zed tasks that can be run from the command palette.
      '';
    };

    userDebug = mkOption {
      inherit (jsonFormat) type;
      default = [ ];
      example = [
        {
          label = "Example";
          adapter = "CodeLLDB";
          request = "launch";
          program = "$ZED_FILE";
        }
      ];
      description = ''
        Configuration written to Zed's `debug.json`.

        These are global debug configurations for Zed's debugger.
      '';
    };

    extensions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "nix"
        "toml"
      ];
      description = ''
        A list of Zed extensions to install on startup.

        The values are translated into the `auto_install_extensions`
        setting in `settings.json`.
      '';
    };

    themes = mkOption {
      type = types.attrsOf (
        types.oneOf [
          jsonFormat.type
          types.path
          types.lines
        ]
      );
      default = { };
      example = lib.literalExpression ''
        {
          my-theme = {
            name = "My Theme";
            author = "Me";
            themes = [ ];
          };
        }
      '';
      description = ''
        Themes written to `zed/themes/<name>.json`.

        Attribute names become theme file names.

        Values may be JSON-like Nix values, raw JSON strings, or paths to
        existing theme files.
      '';
    };

    linkConfig = mkEnableOption ''
      symlinking generated Zed configuration into `$XDG_CONFIG_HOME/zed`
      before launching Zed
    '';

    forceSymlinks = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to replace existing files or symlinks in `$XDG_CONFIG_HOME/zed`
        when linking generated Zed configuration.

        If disabled, the wrapper refuses to overwrite existing files that are
        not already the expected symlink.
      '';
    };

    generatedConfig = {
      output = mkOption {
        type = types.str;
        default = config.outputName;
        description = ''
          The derivation output where the generated Zed configuration is placed.
        '';
      };

      relPath = mkOption {
        type = types.str;
        default = "${config.binName}-config";
        description = ''
          Relative path inside the wrapper derivation where generated Zed
          configuration files are placed.
        '';
      };

      path = mkOption {
        type = types.str;
        default = "${placeholder config.generatedConfig.output}/${config.generatedConfig.relPath}";
        readOnly = true;
        description = ''
          Placeholder path to the generated Zed configuration, available inside
          the wrapper derivation build script.
        '';
      };

      outPath = mkOption {
        type = types.str;
        default = "${config.wrapper.${config.generatedConfig.output}}/${config.generatedConfig.relPath}";
        readOnly = true;
        description = ''
          Final store path to the generated Zed configuration.
        '';
      };
    };
  };

  config = {
    binName = mkDefault "zeditor";
    package = mkDefault pkgs.zed-editor;

    linkConfig = mkDefault true;

    meta = {
      description = ''
        Wraps Zed with declarative settings, keymaps, tasks, debug
        configurations, themes, extensions, and runtime PATH additions.
      '';

      maintainers = [
        wlib.maintainers.sibaldh
      ];
    };

    constructFiles =
      optionalAttrs (generatedSettings != { }) {
        zedSettings = mkJsonFile "${config.generatedConfig.relPath}/zed/settings.json" generatedSettings;
      }
      // optionalAttrs (config.userKeymaps != [ ]) {
        zedKeymaps = mkJsonFile "${config.generatedConfig.relPath}/zed/keymap.json" config.userKeymaps;
      }
      // optionalAttrs (config.userTasks != [ ]) {
        zedTasks = mkJsonFile "${config.generatedConfig.relPath}/zed/tasks.json" config.userTasks;
      }
      // optionalAttrs (config.userDebug != [ ]) {
        zedDebug = mkJsonFile "${config.generatedConfig.relPath}/zed/debug.json" config.userDebug;
      }
      // lib.mapAttrs' (
        name: value: lib.nameValuePair "zedTheme-${name}" (mkThemeFile name value)
      ) generatedThemes;

    buildCommand.zedPathThemes = mkIf (pathThemes != { }) {
      after = [ "constructFiles" ];
      before = [
        "makeWrapper"
        "symlinkScript"
      ];

      data = ''
        mkdir -p ${lib.escapeShellArg "${generatedZedConfigDir}/themes"}
      ''
      + lib.concatMapAttrsStringSep "\n" (name: value: ''
        ln -sfn ${lib.escapeShellArg value} ${lib.escapeShellArg "${generatedZedConfigDir}/themes/${name}.json"}
      '') pathThemes;
    };

    runShell = mkIf (hasGeneratedConfig && config.linkConfig) [
      {
        name = "NIX_ZED_LINK_CONFIG";
        "esc-fn" = wlib.escapeShellArgWithEnv;

        data = ''
          nix_zed_config=${generatedZedConfigDir}
          user_zed_config="''${XDG_CONFIG_HOME:-$HOME/.config}/zed"
          force_symlinks=${if config.forceSymlinks then "1" else "0"}

          link_generated_zed_file() {
            src="$1"
            rel="''${src#$nix_zed_config/}"
            dst="$user_zed_config/$rel"

            mkdir -p "$(dirname "$dst")"

            if [ -L "$dst" ]; then
              current="$(readlink "$dst")"

              if [ "$current" = "$src" ]; then
                return 0
              fi

              if [ "$force_symlinks" = "1" ]; then
                rm "$dst"
              else
                echo "zed wrapper: refusing to replace existing symlink: $dst" >&2
                echo "zed wrapper: set forceSymlinks = true to replace it." >&2
                exit 1
              fi
            elif [ -e "$dst" ]; then
              if [ "$force_symlinks" = "1" ]; then
                rm -rf "$dst"
              else
                echo "zed wrapper: refusing to replace existing file: $dst" >&2
                echo "zed wrapper: set forceSymlinks = true to replace it." >&2
                exit 1
              fi
            fi

            ln -s "$src" "$dst"
          }

          if [ -d "$nix_zed_config" ]; then
            find "$nix_zed_config" \( -type f -o -type l \) -print |
              while IFS= read -r file; do
                link_generated_zed_file "$file"
              done
          fi
        '';
      }
    ];

    passthru.generatedConfig = config.generatedConfig.outPath;
  };
}
