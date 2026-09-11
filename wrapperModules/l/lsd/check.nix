{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    test
    ;
  wm = self.wrappers.lsd;
in
test { wrapper = "lsd"; } {
  "wrapper should output correct version" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
      };
    in
    ''${wrapper}/bin/lsd --version | grep -q "${wrapper.version}"'';

  "config file contains some settings and it applied" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings = {
          classic = true;
          blocks = [
            "size"
            "name"
          ];
          size = "bytes";
        };
      };
    in
    [
      (fileContains "${wrapper.generatedConfig}config.yaml" "classic")
      (fileContains "${wrapper.generatedConfig}config.yaml" "blocks")
      (fileContains "${wrapper.generatedConfig}config.yaml" "bytes")
      # check the lsd output and that it actually used the config
      "${wrapper}/bin/lsd --long ${wrapper.generatedConfig}config.yaml | grep -qE '^48.*config.yaml$'"
    ];

  "custom icons used" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings = {
          icons.when = "always";
          color.when = "never";
          blocks = [
            "name"
          ];
        };
        icons = {
          extension = {
            "yaml" = "";
          };
        };
      };
    in
    [
      (fileContains "${wrapper.generatedConfig}config.yaml" "when: always")
      (fileContains "${wrapper.generatedConfig}icons.yaml" "yaml: ")
      # check the lsd output and that it actually used the config
      "${wrapper}/bin/lsd --long ${wrapper.generatedConfig}icons.yaml | grep -qE '^.*icons.yaml$'"
    ];
  "custom color used" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings = {
          icons.when = "never";
          color.when = "always";
          blocks = [
            "size"
            "name"
          ];
          size = "bytes";
        };
        colors = {
          size = {
            small = "cyan";
          };
        };
      };
    in
    [
      (fileContains "${wrapper.generatedConfig}config.yaml" "theme: custom")
      (fileContains "${wrapper.generatedConfig}colors.yaml" "small: cyan")
      # check the lsd output and that it actually used the config
      "${wrapper}/bin/lsd --long ${wrapper.generatedConfig}colors.yaml | grep -qE '\\[38;5;14m20.*colors.yaml$'"
    ];
}
