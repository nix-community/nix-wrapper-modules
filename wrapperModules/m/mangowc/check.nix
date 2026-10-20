{
  pkgs,
  self,
  ...
}:
let
  mangowcWrapped = self.wrappers.mangowc.wrap (
    { config, lib, ... }:
    let
      oldKeys = builtins.compareVersions config.package.version "0.18.0" < 0;
    in
    {
      inherit pkgs;

      settings = {
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

        # Use lists for duplicate keys like bind and tag_rule
        bind = [
          "SUPER,Y,spawn,slstatus"
          "SUPER+SHIFT,Y,killclient,"
          "ALT,R,setkeymode,resize" # Enter resize mode
        ];

        ${if oldKeys then "tagrule" else "tag_rule"} = [
          "id:1,layout_name:tile"
          "id:2,layout_name:scroller"
        ];

        # Keymodes (submaps) for modal keybindings
        key_mode = {
          resize = {
            bind = [
              "NONE,Left,resizewin,-10,0"
              "NONE,Escape,setkeymode,default"
            ];
          };
        };
      };

      sourcedFiles = lib.mkIf (!oldKeys) [
        ./config.conf
      ];

      autostart_sh = ''
        # spawn terminal on startup
        ${pkgs.lib.getExe pkgs.foot}
      '';

      extraConfig = ''
        # quit
        bind=SUPER,Q,quit
      '';
    }
  );
in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappers.mangowc.meta.platforms then
  pkgs.runCommand "mangowc-test" { } ''
    cat ${mangowcWrapped}/bin/mango
    cat ${mangowcWrapped}/config.conf
    "${mangowcWrapped}/bin/mango" -v | grep -q "${mangowcWrapped.version}"
    "${mangowcWrapped}/bin/mango" -p
    touch $out
  ''
else
  null
