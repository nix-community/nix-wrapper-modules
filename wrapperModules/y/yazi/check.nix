{
  pkgs,
  self,
  tlib,
  ...
}:
let
  yaziWrapper = self.wrappers.yazi.wrap {
    inherit pkgs;

    settings = {
      yazi = {
        mgr = {
          ratio = [
            1
            2
            3
          ];
          sort_by = "natural";
        };

        # Test freeform values in addition to declared options.
        custom_yazi_setting = true;
      };

      keymap = {
        mgr = {
          prepend_keymap = [
            {
              on = [ "q" ];
              run = "quit";
            }
          ];
        };
      };

      theme = {
        flavor = {
          dark = "custom";
        };
      };

      vfs = {
        services = {
          "application/x-example" = "example";
        };
      };

      package = {
        plugin = {
          deps = [
            "yazi-rs/plugins:git.yazi"
          ];
        };
      };
    };

    plugins = {
      git = pkgs.yaziPlugins.git;
      "smart-enter" = pkgs.yaziPlugins.smart-enter;
    };

    flavors = {
      custom = pkgs.yaziPlugins.nord;
    };
  };

  configDir = yaziWrapper.generatedConfig;
  inherit (tlib) isDirectory isFile fileContains;
in
tlib.test { wrapper = "yazi"; } {
  generated-files = [
    (isDirectory configDir)
    (isFile "${configDir}/yazi.toml")
    (isFile "${configDir}/keymap.toml")
    (isFile "${configDir}/theme.toml")
    (isFile "${configDir}/vfs.toml")
    (isFile "${configDir}/package.toml")
  ];

  yazi-settings = [
    (fileContains "${configDir}/yazi.toml" ''ratio = \[1, 2, 3\]'')
    (fileContains "${configDir}/yazi.toml" ''sort_by = "natural"'')
    (fileContains "${configDir}/yazi.toml" "custom_yazi_setting = true")
  ];

  keymap-settings = [
    (fileContains "${configDir}/keymap.toml" "prepend_keymap")
    (fileContains "${configDir}/keymap.toml" ''on = \["q"\]'')
    (fileContains "${configDir}/keymap.toml" ''run = "quit"'')
  ];

  theme-settings = [
    (fileContains "${configDir}/theme.toml" ''dark = "custom"'')
  ];

  vfs-settings = [
    (fileContains "${configDir}/vfs.toml" ''"application/x-example" = "example"'')
  ];

  package-settings = [
    (fileContains "${configDir}/package.toml" ''"yazi-rs/plugins:git.yazi"'')
  ];

  plugins = [
    (isDirectory "${configDir}/plugins")
    (isDirectory "${configDir}/plugins/git.yazi")
    (isDirectory "${configDir}/plugins/smart-enter.yazi")
  ];

  flavors = [
    (isDirectory "${configDir}/flavors")
    (isDirectory "${configDir}/flavors/custom.yazi")
  ];
}
