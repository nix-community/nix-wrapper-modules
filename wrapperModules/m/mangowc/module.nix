{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    wlib.modules.default
    wlib.modules.systemd
  ];

  options =
    let
      inherit (lib)
        literalExpression
        mkOption
        mkOptionDefault
        types
        ;
    in
    {
      settings = mkOption {
        type =
          with types;
          let
            valueType =
              nullOr (oneOf [
                bool
                int
                float
                str
                path
                (attrsOf valueType)
                (listOf valueType)
              ])
              // {
                description = "Mango configuration value";
              };
          in
          valueType;
        default = { };
        description = ''
          Mango configuration written in Nix. Entries with the same key
          should be written as lists. Variables and colors names should be
          quoted. See <https://mangowc.vercel.app/docs> for more examples.

          Note: This option uses a structured format that is converted to Mango's
          configuration syntax. Nested attributes are flattened with underscore separators.
          For example: `animation.duration_open = 400` becomes `animation_duration_open = 400`

          Keymodes (submaps) are supported via the special `keymode` attribute. Each keymode
          is a nested attribute set under `keymode` that contains its own bindings.
        '';
        example = literalExpression ''
          {
            # Window effects
            blur = 1;
            blur_optimized = 1;
            blur_params = {
              radius = 5;
              num_passes = 2;
            };
            border_radius = 6;
            focused_opacity = 1.0;

            # Animations - use underscores for multi-part keys
            animations = 1;
            animation_type_open = "slide";
            animation_type_close = "slide";
            animation_duration_open = 400;
            animation_duration_close = 800;

            # Or use nested attrs (will be flattened with underscores)
            animation_curve = {
              open = "0.46,1.0,0.29,1";
              close = "0.08,0.92,0,1";
            };

            # Use lists for duplicate keys like bind and tagrule
            bind = [
              "SUPER,r,reload_config"
              "Alt,space,spawn,rofi -show drun"
              "Alt,Return,spawn,foot"
              "ALT,R,setkeymode,resize"  # Enter resize mode
            ];

            tagrule = [
              "id:1,layout_name:tile"
              "id:2,layout_name:scroller"
            ];

            # Keymodes (submaps) for modal keybindings
            keymode = {
              resize = {
                bind = [
                  "NONE,Left,resizewin,-10,0"
                  "NONE,Escape,setkeymode,default"
                ];
              };
            };
          }
        '';
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Extra configuration lines to add to the end of the generated config file.
          This is useful for advanced configurations that don't fit the structured
          settings format, or for options that aren't yet supported by the module.
        '';
        example = ''
          # Advanced config that doesn't fit structured format
          special_option = 1
        '';
      };

      topPrefixes = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of prefixes for attributes that should appear at the top of the config file.
          Attributes starting with these prefixes will be sorted to the beginning.
        '';
        example = [ "source" ];
      };

      bottomPrefixes = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of prefixes for attributes that should appear at the bottom of the config file.
          Attributes starting with these prefixes will be sorted to the end.
        '';
        example = [ "source" ];
      };

      autostart_sh = mkOption {
        description = ''
          Shell script to run on mango startup. No shebang needed.

          When this option is set, the script will be written to
          `~/.config/mango/autostart.sh` and an `exec-once` line
          will be automatically added to the config to execute it.
        '';
        type = types.lines;
        default = "";
        example = ''
          waybar &
          dunst &
        '';
      };

      sourcedFiles = mkOption {
        type = types.listOf wlib.types.stringable;
        description = ''
          Paths to files that will be sourced at the top of the generated config file.
        '';
        default = [ ];
        example = literalExpression ''
          [
            ./config.conf
            ./binds.conf
            ./theme.conf
          ]
        '';
      };

      configFile = mkOption {
        type = wlib.types.file {
          path = mkOptionDefault config.constructFiles.generatedConfig.path;
        };
        default = { };
        description = ''
          The config file that mango will set as its primary config file.
          By default, this file will be generated from whatever the other options are set to.

          Note: If `configFile.path` is set, it will be used INSTEAD of the generated configuration. The generated file will still be created, however, and you can source it. If you don't want the generated config to get overwritten, add the path you want to use to the `sourcedFiles` option and don't set `configFile.path`.

          If `configFile.content` is set, it will replace the contents of the generated config file entirely. If you don't want the generated config to get overwritten, set the `extraConfig` option and don't set `configFile.content`.
        '';
        example = literalExpression ''
          {
            path = ./config.conf;
            # or
            content = "bind=Alt,space,spawn,rofi -show drun";
          }
        '';
      };

      hotReload.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          When `true`, the wrapper will generate mango-reload service which will reload mango with the new config on rebuild.

          Note: You have to start the mango-reload.service yourself.
          For Example:
          ```
            systemd.packages = [ config.wrappers.mango.wrapper ];
            wrappers.mango.settings.exec-once = [
              "systemctl --user start mango-reload.service"
            ];
          ```

          Mango 0.15 is required for this functionality.
        '';
      };
    };

  config = {
    # Gives an error when using a bad config.
    drv.installPhase = ''
      runHook preInstall
      ${lib.getExe config.package} -c ${config.configFile.path} -p
      runHook postInstall
    '';

    constructFiles.generatedConfig = {
      relPath = "config.conf";
      content =
        if config.configFile.content or "" != "" then
          config.configFile.content
        else
          let
            settingsString =
              let
                inherit (import ./lib.nix lib) toMango;
              in
              toMango {
                topCommandsPrefixes = config.topPrefixes;
                bottomCommandsPrefixes = config.bottomPrefixes;
              } config.settings;
            isImpurePath = s: builtins.isString s && !builtins.hasContext s;
            sourcedFileToSourceExpression =
              sourcedFile:
              if isImpurePath sourcedFile then "source-optional=${sourcedFile}" else "source=${sourcedFile}";
          in
          (lib.strings.concatMapStringsSep "\n" sourcedFileToSourceExpression config.sourcedFiles)
          + "\n"
          + settingsString
          + "\n"
          + config.extraConfig
          + "\n"
          + lib.optionalString (
            config.autostart_sh != ""
          ) "\nexec-once=${config.constructFiles.autostart_sh.path}\n";
    };

    constructFiles.autostart_sh = {
      relPath = "autostart_sh";
      content = config.autostart_sh;
      builder = ''
        printf '%s\n' ${lib.escapeShellArg "#!${pkgs.bash}${pkgs.bash.shellPath}"} > "$2" && cat "$1" >> "$2" && chmod +x "$2"
      '';
    };

    systemd.user.service.mangoReloadConfig = lib.mkIf config.hotReload.enable {
      Service = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${lib.getExe' pkgs.coreutils "true"}";
        ExecReload = "${lib.getExe' config.package "mmsg"} dispatch load_config_file,${config.constructFiles.generatedConfig.path}";
        X-ReloadIfChanged = true;
      };
      Unit.X-Reload-Triggers = [ config.constructFiles.generatedConfig.path ];
    };

    flags."-c" = config.configFile.path;
    package = lib.mkDefault (pkgs.mangowc or pkgs.mango);
    passthru.providedSessions = config.package.passthru.providedSessions;

    meta.platforms = lib.platforms.linux;
    meta.maintainers = [ wlib.maintainers.pengolord ];
  };
}
