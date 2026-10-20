{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    isDirectory
    isFile
    test
    ;

  wrapper = self.wrappers.zed.wrap {
    inherit pkgs;

    userSettings = {
      vim_mode = true;
      telemetry.metrics = false;
    };

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          ctrl-shift-t = "workspace::NewTerminal";
        };
      }
    ];

    userTasks = [
      {
        label = "nix flake check";
        command = "nix";
        args = [
          "flake"
          "check"
        ];
      }
    ];

    userDebug = [
      {
        label = "Example";
        adapter = "CodeLLDB";
        request = "launch";
        program = "$ZED_FILE";
      }
    ];

    extensions = [ "nix" ];

    themes.example = {
      name = "Example";
      author = "nix-wrapper-modules";
      themes = [ ];
    };
  };

in
test { wrapper = "zed"; } {
  "zed wrapper should be created" = [
    (isDirectory wrapper)
    (isFile "${wrapper}/bin/zeditor")
  ];

  "zed settings should be generated" = [
    (isFile "${wrapper.generatedConfig}/zed/settings.json")
    (fileContains "${wrapper.generatedConfig}/zed/settings.json" "vim_mode")
    (fileContains "${wrapper.generatedConfig}/zed/settings.json" "auto_install_extensions")
  ];

  "zed keymaps should be generated" = [
    (isFile "${wrapper.generatedConfig}/zed/keymap.json")
    (fileContains "${wrapper.generatedConfig}/zed/keymap.json" "workspace::NewTerminal")
  ];

  "zed tasks should be generated" = [
    (isFile "${wrapper.generatedConfig}/zed/tasks.json")
    (fileContains "${wrapper.generatedConfig}/zed/tasks.json" "nix flake check")
  ];

  "zed debug config should be generated" = [
    (isFile "${wrapper.generatedConfig}/zed/debug.json")
    (fileContains "${wrapper.generatedConfig}/zed/debug.json" "CodeLLDB")
  ];

  "zed themes should be generated" = [
    (isFile "${wrapper.generatedConfig}/zed/themes/example.json")
    (fileContains "${wrapper.generatedConfig}/zed/themes/example.json" "Example")
  ];
}
