{
  pkgs,
  self,
  tlib,
  lib,
  ...
}:

let
  mkEnvPrint =
    wrapper: wrapper.configuration.pkgs.runCommand "nh env test" { } "${lib.getExe wrapper} > $out";
in
tlib.test { wrapper = "nh"; } {
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
        rom = false;
        flake = "/foo/bar";
        searchChannel = "nixos-26.05";

        extraConfig = {
          LOG = "verbose";
        };
      };
      scriptContains = tlib.fileContains (mkEnvPrint wrapper);
    in
    [
      (scriptContains "NH_ASK=1")
      (scriptContains "NH_ROM=")
      (scriptContains "NH_FLAKE=/foo/bar")
      (scriptContains "NH_SEARCH_CHANNEL=nixos-26.05")
      (scriptContains "NH_LOG=verbose")
    ];

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
      scriptContains = tlib.fileContains (mkEnvPrint wrapper);
    in
    [
      (scriptContains "NH_FLAKE=/foo/bar")
      (scriptContains "NH_SEARCH_CHANNEL=nixos-26.05")
    ];
}
