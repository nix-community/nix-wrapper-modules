{
  pkgs,
  self,
  tlib,
  ...
}:
let
  inherit (tlib)
    isFile
    fileContains
    notFileContains
    test
    ;

  wrapper = self.wrappers.umbriel.wrap {
    inherit pkgs;
    settings = {
      general = {
        autostart = [ "noctalia" ];
        show_cheatsheet = false;
      };
      layout.gap = 5;
      input.keyboard.layout = "us";
      keybinds = {
        "Mod+Tab" = "overview-toggle";
        "Mod+T" = "spawn ghostty";
      };
    };
  };

  rawTomlWrapper = self.wrappers.umbriel.wrap {
    inherit pkgs;
    "config.toml".content = ''
      [layout]
      gap = 9
    '';
  };

  script = "${wrapper}/bin/umbriel";
  userConfigFile = "${wrapper}/umbriel-user-config.toml";
  configFile = "${wrapper}/umbriel.toml";
in
test { wrapper = "umbriel"; } {
  "umbriel wrapper binary should exist" = [ (isFile script) ];

  "umbriel wrapper should pass the generated config via -c" = [
    (fileContains script "set -- -c")
    (fileContains script "umbriel.toml")
  ];

  "umbriel wrapper should only add -c when starting the compositor" = [
    (fileContains script "-eq 0")
    (fileContains script "= \"-s\"")
  ];

  "umbriel attrset settings should be translated to TOML" = [
    (isFile configFile)
    (isFile userConfigFile)
    (fileContains configFile "^\\[include\\]")
    (fileContains userConfigFile "^\\[general\\]")
    (fileContains userConfigFile "show_cheatsheet = false")
    (fileContains userConfigFile "gap = 5")
    (fileContains userConfigFile "layout = \"us\"")
    (fileContains userConfigFile "\"Mod\\+Tab\" = \"overview-toggle\"")
    (fileContains userConfigFile "\"Mod\\+T\" = \"spawn ghostty\"")
  ];

  "umbriel raw string settings should be written as is" = [
    (fileContains "${rawTomlWrapper}/umbriel.toml" "gap = 9")
    (fileContains "${rawTomlWrapper}/bin/umbriel" "set -- -c")
  ];

  "umbriel session files should reference the wrapper, not the original package" = [
    (isFile "${wrapper}/bin/start-umbriel")
    (fileContains "${wrapper}/bin/start-umbriel" "${wrapper}/bin/umbriel")
    (notFileContains "${wrapper}/bin/start-umbriel" "${pkgs.umbriel}/bin/umbriel")
    (isFile "${wrapper}/lib/systemd/user/umbriel.service")
    (fileContains "${wrapper}/lib/systemd/user/umbriel.service" "ExecStart=${wrapper}/bin/umbriel")
  ];

  "umbriel wrapper should bypass -c flag for --version" = ''
    "${script}" --version | grep -q "umbriel"
  '';
}
