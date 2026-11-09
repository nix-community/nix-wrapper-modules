{
  config,
  pkgs,
  wlib,
  lib,
  ...
}:
let
  mkRule =
    # "window-rules" "layer-rules"
    node: r:
    let
      matches = map (m: { match = _: { props = m; }; }) (r.matches or [ ]);
      excludes = map (m: { exclude = _: { props = m; }; }) (r.excludes or [ ]);
      other = lib.mapAttrsToList (n: v: { ${n} = v; }) (
        lib.attrsets.removeAttrs r [
          "matches"
          "excludes"
        ]
      );
    in
    {
      ${node} = matches ++ excludes ++ other;
    };
  attrAsArg =
    # "workspace" "output"
    node:
    lib.mapAttrsToList (
      n: v: {
        # use the attr name as arg for the named node
        ${node} =
          s:
          if lib.isFunction v then
            let
              res = v s;
            in
            res
            // {
              props =
                if res ? props then
                  if builtins.isAttrs res.props then
                    [
                      n
                      res.props
                    ]
                  else if builtins.isList res.props then
                    [ n ] ++ res.props
                  else
                    n
                else
                  n;
            }
          else if builtins.isAttrs v then
            {
              content = v;
              props = n;
            }
          else
            { props = n; };
      }
    );
in
{
  imports = [
    wlib.modules.default
    wlib.modules.systemd
  ];

  options = {
    settings = lib.mkOption {
      description = ''
        Niri configuration settings.
        See <https://yalter.github.io/niri/Configuration%3A-Introduction.html>

        This is a freeform submodule. If you do not see your option listed,
        try setting it using the format specified by `wlib.toKdl`
      '';
      default = { };
      type = lib.types.submodule {
        freeformType = wlib.types.attrsRecursive;
        options = {
          binds = lib.mkOption {
            default = { };
            type = wlib.types.attrsRecursive;
            description = "Bindings of niri";
            example = lib.literalMD ''
              ```nix
              binds = {
                "Mod+T".spawn-sh = "alacritty";
                "Mod+J".focus-column-or-monitor-left = _: { };
                "Mod+N".spawn = [ "alacritty" "msg" "create-windown" ];
                "Mod+0".focus-workspace = 0;
                "Mod+Escape" = _: {
                  props.allow-inhibiting = false;
                  content.toggle-keyboard-shortcuts-inhibit = _: { }; # <- _: { } is translated to nothing
                };
              };
              ```
            '';
          };
          layout = lib.mkOption {
            default = { };
            type = wlib.types.attrsRecursive;
            description = "Layout definitions";
            example = lib.literalMD ''
              ```nix
              layout = {
                focus-ring.off = _: { };
                border = {
                  width = 3;
                  active-color = "#f5c2e7";
                  inactive-color = "#313244";
                };
                preset-column-widths = [
                  { proportion = 0.5; }
                  { proportion = 0.666667; }
                ];
              };
              ```
            '';
          };
          spawn-at-startup = lib.mkOption {
            default = [ ];
            type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
            description = ''
              List of commands to run at startup.
              The first element in a passed list will be run with the following elements as arguments
            '';
            example = [
              "hello"
              [
                "nix"
                "build"
              ]
            ];
          };
          spawn-sh-at-startup = lib.mkOption {
            default = [ ];
            type = lib.types.listOf lib.types.str;
            description = ''
              List of sh commands as strings to run at startup.
            '';
            example = [
              "sleep 1 && echo 'hello world'"
              "kitty"
            ];
          };
          window-rules = lib.mkOption {
            default = [ ];
            type = lib.types.listOf lib.types.attrs;
            description = "List of window rules";
            example = [
              {
                matches = [ { app-id = ".*"; } ];
                excludes = [
                  { app-id = "org.keepassxc.KeePassXC"; }
                  { app-id = _: { custom = ''r#"^org\.telegram\.desktop$"#''; }; }
                ];
                open-focused = false;
                open-floating = false;
              }
            ];
          };
          layer-rules = lib.mkOption {
            default = [ ];
            type = lib.types.listOf lib.types.attrs;
            description = "List of layer rules";
            example = [
              {
                matches = [ { namespace = "^notifications$"; } ];
                block-out-from = "screen-capture";
                opacity = 0.8;
              }
            ];
          };
          workspaces = lib.mkOption {
            default = { };
            type = lib.types.attrsOf (lib.types.nullOr lib.types.anything);
            description = "Named workspace definitions";
            example = lib.literalMD ''
              ```nix
              workspaces = {
                "foo" = {
                  open-on-output = "DP-3";
                };
                "bar" = _: { };
              };
              ```
            '';
          };
          outputs = lib.mkOption {
            default = { };
            type = wlib.types.attrsRecursive;
            description = "Output configuration";
            example = lib.literalMD ''
              ```nix
              {
                "DP-3" = {
                  position = _: {
                    props = {
                      x = 1440;
                      y = 1080;
                    };
                  };
                  background-color = "#003300";
                  hot-corners = {
                    off = _: { };
                  };
                };
              }
              ```
            '';
          };
          extraConfig = lib.mkOption {
            default = "";
            type = lib.types.lines;
            description = ''
              Escape hatch string option added to the config file for
              options that might not be representable otherwise,
              due to `config.settings` in this module being required to be an attribute set.
            '';
          };
        };
      };
    };
    extraSettings = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf wlib.types.attrsRecursive);
      default = [ ];
      description = ''
        Allows for auto translated kdl values for options not included in `config.settings`,
        but for which repeated definitions are significant.

        Syntax for this option is the list form for the `wlib.toKdl` function
      '';
      example = lib.literalMD ''
        ```nix
        config.extraSettings = [
          { include = ./some/pure/path; }
          # If `include optional=true "~/some/impure/path"` is not valid in your version of niri, you may want to use their flake!
          { include = [ { optional = true; } "~/some/impure/path" ]; }
        ];
        ```
      '';
    };
    "config.kdl" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default = { };
      description = ''
        Configuration file for Niri.
        See <https://github.com/YaLTeR/niri/wiki/Configuration:-Introduction>

        If `config."config.kdl".content` is non-empty, its content will be used instead of the generated
        config from `config.settings` in the generated config file in the derivation.

        You may also set `config."config.kdl".path` to your own path.

        This will still allow the generated config to be created from `config.settings`

        You could use the include feature to include it.
      '';
      example = lib.literalMD ''
        ```nix
        # Overwrite the generated config
        config."config.kdl".content = /* kdl */ '''
          input {
            keyboard {
                numlock
            }
            touchpad {
                tap
                natural-scroll
            }
            focus-follows-mouse "max-scroll-amount"="0%" {
            }
          }
        ''';
        ```
      '';
    };
    disableConfigValidation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When `true`, the wrapper will not run `niri validate` on the nix-provided config file.

        This is useful for debugging the output of the generated config file.

        It also allows you to pass an impure path via `config."config.kdl".path`,
        as nix no longer needs to know about this path at build time.
      '';
    };
    disableConfigHotReload = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When `true`, the wrapper will not hot reload niri with the new config on rebuild.

        Note: Niri 26.04 is required for this functionality.
      '';
    };
  };
  config.filesToPatch = [
    "share/applications/*.desktop"
    "lib/systemd/user/niri.service"
    "share/systemd/user/niri.service"
  ];
  # NOTE: gives users a nice error message about invalid configs, with actual knowledge of niri's config format
  config.drv.installPhase = lib.mkIf (!config.disableConfigValidation) ''
    runHook preInstall
    ${lib.getExe config.package} validate -c ${config.constructFiles.generatedConfig.path}
    runHook postInstall
  '';
  config.package = lib.mkDefault pkgs.niri;
  config.env.NIRI_CONFIG = config."config.kdl".path;
  config.constructFiles.generatedConfig = {
    relPath = "${config.binName}-config.kdl";
    content =
      if config."config.kdl".content or "" != "" then
        config."config.kdl".content
      else
        wlib.toKdl (_: {
          version = 1;
          content = builtins.concatLists [
            (map (mkRule "window-rule") config.settings.window-rules)
            (map (mkRule "layer-rule") config.settings.layer-rules)
            (map (v: { spawn-at-startup = _: { props = v; }; }) config.settings.spawn-at-startup)
            (map (v: { spawn-sh-at-startup = _: { props = v; }; }) config.settings.spawn-sh-at-startup)
            (attrAsArg "workspace" config.settings.workspaces)
            (attrAsArg "output" config.settings.outputs)
            [
              (lib.removeAttrs config.settings [
                "window-rules"
                "layer-rules"
                "spawn-at-startup"
                "spawn-sh-at-startup"
                "workspaces"
                "outputs"
                "extraConfig"
              ])
            ]
            config.extraSettings
          ];
        })
        + "\n"
        + config.settings.extraConfig;
  };
  config.systemd.user.service.niri = lib.mkIf (!config.disableConfigHotReload) {
    Unit.X-Reload-Triggers = [ "${config.constructFiles.generatedConfig.path}" ];
    Service = {
      ExecReload = "${lib.getExe config.package} msg action load-config-file --path ${config.constructFiles.generatedConfig.path}";
      X-ReloadIfChanged = true;
    };
  };
  config.meta.maintainers = [
    wlib.maintainers.patwid
  ];
  config.meta.platforms = lib.platforms.linux;
  config.passthru.providedSessions = pkgs.niri.passthru.providedSessions;
}
