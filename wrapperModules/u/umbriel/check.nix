{
  pkgs,
  self,
  tlib,
  ...
}:
let
  inherit (tlib)
    isFile
    notIsFile
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
        "Mod+T" = "spawn:ghostty";
      };
    };
  };

  pathWrapper = self.wrappers.umbriel.wrap {
    inherit pkgs;
    settings = pkgs.writeText "umbriel-path.toml" ''
      [layout]
      gap = 7
    '';
  };

  textWrapper = self.wrappers.umbriel.wrap {
    inherit pkgs;
    settings = ''
      [layout]
      gap = 9
    '';
  };

  emptyWrapper = self.wrappers.umbriel.wrap { inherit pkgs; };

  script = "${wrapper}/bin/umbriel";
  configFile = "${wrapper}/umbriel-config.toml";
in
test { wrapper = "umbriel"; } {
  "umbriel wrapper binary should exist" = [ (isFile script) ];

  "umbriel wrapper should pass the generated config via -c" = [
    (fileContains script "set -- -c")
    (fileContains script "umbriel-config.toml")
  ];

  "umbriel wrapper should only add -c when starting the compositor" = [
    (fileContains script "-eq 0")
    (fileContains script "= \"-s\"")
  ];

  "umbriel attrset settings should be translated to TOML" = [
    (isFile configFile)
    (fileContains configFile "^\\[general\\]")
    (fileContains configFile "show_cheatsheet = false")
    (fileContains configFile "gap = 5")
    (fileContains configFile "layout = \"us\"")
    (fileContains configFile "\"Mod\\+Tab\" = \"overview-toggle\"")
    (fileContains configFile "\"Mod\\+T\" = \"spawn:ghostty\"")
  ];

  "umbriel path settings should be copied as is" = [
    (fileContains "${pathWrapper}/umbriel-config.toml" "gap = 7")
    (fileContains "${pathWrapper}/bin/umbriel" "set -- -c")
  ];

  "umbriel raw string settings should be written as is" = [
    (fileContains "${textWrapper}/umbriel-config.toml" "gap = 9")
    (fileContains "${textWrapper}/bin/umbriel" "set -- -c")
  ];

  "umbriel with empty settings should not set a config" = [
    (notIsFile "${emptyWrapper}/umbriel-config.toml")
    (notFileContains "${emptyWrapper}/bin/umbriel" "set -- -c")
  ];

  "umbriel session files should reference the wrapper, not the original package" = [
    (isFile "${wrapper}/bin/start-umbriel")
    (fileContains "${wrapper}/bin/start-umbriel" "${wrapper}/bin/umbriel")
    (notFileContains "${wrapper}/bin/start-umbriel" "${pkgs.umbriel}/bin/umbriel")
    (isFile "${wrapper}/lib/systemd/user/umbriel.service")
    (fileContains "${wrapper}/lib/systemd/user/umbriel.service" "ExecStart=${wrapper}/bin/umbriel")
    (notFileContains "${wrapper}/lib/systemd/user/umbriel.service" "${pkgs.umbriel}/bin/umbriel")
  ];

  "umbriel wrapper should bypass -c flag for --version" = ''
    "${script}" --version | grep -q "umbriel"
  '';
}
