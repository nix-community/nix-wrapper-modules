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
    test
    ;
  wm = self.wrappers.bat;

in
test { wrapper = "bat"; } {
  "wrapper should output correct version" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
      };
    in
    ''${wrapper}/bin/bat --version | grep -q "${wrapper.version}"'';

  "Lists in settings should be handled correctly" =
    let
      wrapper = wm.wrap {
        inherit pkgs;
        settings = {
          map-syntax = [
            "*.yaml.template:YAML"
            "*.lock:JSON"
          ];
        };

      };
    in
    [
      (fileContains "${wrapper}/bat-config/config" "--map-syntax .\*.lock:JSON.")
      (fileContains "${wrapper}/bat-config/config" "--map-syntax .\*.yaml.template:YAML.")
    ];

}
