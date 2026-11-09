{
  pkgs,
  self,
  ...
}:

let
  niriWrapped = self.wrappers.niri.wrap {
    inherit pkgs;

    settings = {
      binds = {
        "Mod+T".spawn-sh = "alacritty";
        "Mod+J".focus-column-or-monitor-left = _: { };
        "Mod+N".spawn = [
          "alacritty"
          "msg"
          "create-windown"
        ];
        "Mod+0".focus-workspace = 0;
      };

      window-rules = [
        {
          matches = [ { app-id = ".*"; } ];
          excludes = [
            { app-id = "org.keepassxc.KeePassXC"; }
            { app-id = _: { custom = ''r#"^org\.telegram\.desktop$"#''; }; }
          ];
          open-focused = false;
          open-floating = false;
        }
        #disallow screencapture for keepass,etc.
        {
          matches = [
            { app-id = "org.keepassxc.KeePassXC"; }
            {
              app-id = "thunderbird";
              title = "^Picture-in-Picture$";
            }
          ];
          block-out-from = "screen-capture";
        }
      ];

      layer-rules = [
        {
          matches = [ { namespace = "^notifications$"; } ];
          block-out-from = "screen-capture";
          opacity = 0.8;
        }
      ];

      layout = {
        focus-ring.off = _: { };
        border = {
          width = 3;
          active-color = "#f5c2e7";
          inactive-color = "#313244";
        };

        preset-column-widths = [
          { proportion = 1.0; }
          { proportion = 1.0 / 2.0; }
          { proportion = 1.0 / 3.0; }
          { proportion = 1.0 / 4.0; }
        ];
      };

      workspaces = {
        "foo" = {
          open-on-output = "DP-3";
        };
        "bar" = _: { };
      };

      outputs = {
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
      };

      spawn-at-startup = [
        "hello"
        [
          "nix"
          "build"
        ]
      ];

      spawn-sh-at-startup = [
        "sleep 1 && echo 'hello world'"
        "kitty"
      ];

      hotkey-overlay.skip-at-startup = [ ];
      prefer-no-csd = true;
      overview.zoom = 0.25;
    };
  };
in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappers.niri.meta.platforms then
  pkgs.runCommand "niri-test" { } ''
    cat ${niriWrapped}/bin/niri
    "${niriWrapped}/bin/niri" --version | grep -q "${niriWrapped.version}"
    "${niriWrapped}/bin/niri" validate
    # since config is now checked at build time, testing a bad config is impossible
    touch $out
  ''
else
  null
