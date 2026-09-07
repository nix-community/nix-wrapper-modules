{
  pkgs,
  self,
  tlib,
  ...
}:
let
  inherit (tlib) isFile fileContains test;
  wrapper = self.wrappers.ghostty.wrap {
    inherit pkgs;
    settings = {
      font-size = 14;
      theme = "Catppuccin Mocha";
      window-decoration = false;
      keybind = [
        "ctrl+a>-=new_split:down"
        "ctrl+a>==new_split:right"
      ];
    };
  };
  configFile = "${wrapper}/ghostty-config";
in
test { wrapper = "ghostty"; } {
  "ghostty wrapper binary should exist" = [ (isFile "${wrapper}/bin/ghostty") ];

  "ghostty wrapper should disable default config and point to generated file" = [
    (fileContains "${wrapper}/bin/ghostty" "--config-default-files=false")
    (fileContains "${wrapper}/bin/ghostty" "--config-file=")
  ];

  "ghostty wrapper should bypass config flags for +actions and --help" = [
    (fileContains "${wrapper}/bin/ghostty" "_ghostty_arg")
    (fileContains "${wrapper}/bin/ghostty" "--help")
  ];

  "ghostty config file should exist" = [ (isFile configFile) ];

  "ghostty settings should appear in generated config" = [
    (fileContains configFile "font-size = 14")
    (fileContains configFile "theme = Catppuccin Mocha")
    (fileContains configFile "window-decoration = false")
  ];

  "ghostty list settings should serialize as duplicate keys" = [
    (fileContains configFile "keybind = ctrl\\+a>-=new_split:down")
    (fileContains configFile "keybind = ctrl\\+a>==new_split:right")
  ];
}
