{
  pkgs,
  self,
  tlib,
  lib,
  ...
}:

let
  inherit (tlib) test;
in
test { wrapper = "nh"; } {
  "wrapper initialization" =
    let
      wrapper = self.wrappers.nh.wrap {
        inherit pkgs;
      };
    in
    "[[ -x ${wrapper}/bin/nh ]]";

  "wrapper environment configuration" =
    let
      wrapper = self.wrappers.nh.wrap {
        inherit pkgs;

        package = lib.mkForce (
          pkgs.writeShellScriptBin "nh" ''
            env
          ''
        );
        ask = true;
        nom = false;
        flake = "/foo/bar";
        searchChannel = "nixos-26.05";

        extraConfig = {
          LOG = "verbose";
        };
      };
    in
    ''
      output="$(${wrapper}/bin/nh)"
      [[ "$output" = *"NH_ASK=1"* ]]
      [[ "$output" = *"NH_NOM=0"* ]]
      [[ "$output" = *"NH_FLAKE=/foo/bar"* ]]
      [[ "$output" = *"NH_SEARCH_CHANNEL=nixos-26.05"* ]]
      [[ "$output" = *"NH_LOG=verbose"* ]]
    '';

  "dedicated option precedence" =
    let
      wrapper = self.wrappers.nh.wrap {
        inherit pkgs;

        package = lib.mkForce (
          pkgs.writeShellScriptBin "nh" ''
            env
          ''
        );
        flake = "/foo/bar";
        searchChannel = "nixos-26.05";

        extraConfig = {
          FLAKE = "/bar/baz";
          SEARCH_CHANNEL = "nixos-25.11";
        };
      };
    in
    ''
      output=$(${wrapper}/bin/nh)
      [[ "$output" = *"NH_FLAKE=/foo/bar"* ]]
      [[ "$output" = *"NH_SEARCH_CHANNEL=nixos-26.05"* ]]
    '';
}
