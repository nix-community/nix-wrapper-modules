{
  lib,
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    notFileContains
    test
    ;
  wm = self.wrappers.difftastic;

in
test { wrapper = "difftastic"; } {
  "wrapper should output correct version" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
      };
    in
    ''${wrapper}/bin/difft --version | grep -q "${wrapper.version}"'';

  "If no config is provided then no DFT_ variables and no --override* flags in wrapper script" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
      };
    in
    [
      (notFileContains "${wrapper}/bin/difft" "DFT_")
      (notFileContains "${wrapper}/bin/difft" "--override")
    ];

  "If common settings set wrapper script should have DFT_ variable(s)" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings = {
          check-only = true;
          color = "never";
          tab-width = 2;
        };
      };
    in
    [
      (fileContains "${wrapper}/bin/difft" "DFT_CHECK_ONLY true$")
      (fileContains "${wrapper}/bin/difft" "DFT_COLOR never$")
      (fileContains "${wrapper}/bin/difft" "DFT_TAB_WIDTH 2$")
    ];

  "If override setting set wrapper script should have correct --override flags and their order" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings = {
          override = {
            "*.c" = "c++";
            "flake.lock" = lib.mkBefore "text";
            "package.lock" = lib.mkAfter "json";
          };
        };
      };
    in
    ''grep -Fq -- "'--override=flake.lock:text' '--override=*.c:c++' '--override=package.lock:json'" ${wrapper}/bin/difft'';

  "If override-binary setting set wrapper script should have correct --override-binary flags" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings = {
          override-binary = [
            "*.qcow2"
            "file.iso"
          ];
        };
      };
    in
    ''grep -Fq -- "'--override-binary=*.qcow2' '--override-binary=file.iso'" ${wrapper}/bin/difft'';

  "If min-width setting set wrapper script should have a script to calculate and set width" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings = {
          min-width = 120;
        };
      };
    in
    [
      (fileContains "${wrapper}/bin/difft" "stty size")
      (fileContains "${wrapper}/bin/difft" "wrapperSetEnvDefault DFT_WIDTH 120")
    ];
}
