{
  pkgs,
  self,
  tlib,
}:

let
  inherit (tlib)
    fileContains
    isDirectory
    isFile
    notIsFile
    test
    ;

  lib = pkgs.lib;

  getDotdir =
    wrapper:
    let
      cfg = (wrapper.eval { }).config;
      dotdir = "${wrapper}/${cfg.configDirname}";
    in
    dotdir;
in
test { wrapper = "direnv"; } {

  "direnv wrapper should be created" =
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = true;
      };
    in
    ''
      "${wrapper}/bin/direnv" --version | grep -q "${wrapper.version}"
    '';

  "if nix-direnv is enabled then lib/nix-direnv.sh should exists" =
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = true;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile "${getDotdir wrapper}/lib/nix-direnv.sh")
    ];

  "if nix-direnv is disabled then lib/nix-direnv.sh should not exist" =
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = false;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (notIsFile "${getDotdir wrapper}/lib/nix-direnv.sh")
    ];

  "if mise is enabled then lib/mise.sh should exists" =
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        mise.enable = true;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile "${getDotdir wrapper}/lib/mise.sh")
    ];

  "if mise is disabled then lib/mise.sh should not exist" =
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        mise.enable = false;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (notIsFile "${getDotdir wrapper}/lib/mise.sh")
    ];

  "if a lib-script is set then it should be generated" =
    let
      libScriptFile = "${getDotdir wrapper}/lib/foo.sh";
      libScriptContent = "echo foo";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        lib."foo.sh" = libScriptContent;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile libScriptFile)
      (fileContains libScriptFile libScriptContent)
    ];

  "if silent mode is enabled then log settings should be set" =
    let
      direnvTomlFile = "${getDotdir wrapper}/direnv.toml";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        silent = true;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile direnvTomlFile)
      (fileContains direnvTomlFile "log_format")
      (fileContains direnvTomlFile "log_filter")

    ];

  "if extraConfig is working" =
    let
      direnvTomlFile = "${getDotdir wrapper}/direnv.toml";
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        extraConfig = {
          fooSection.fooKey = "fooValue";
        };
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile direnvTomlFile)
      (fileContains direnvTomlFile "\\[fooSection\\]")
      (fileContains direnvTomlFile "fooKey.*fooValue")
    ];

  "if direnvrc is working" =
    let
      direnvrcFile = "${getDotdir wrapper}/direnvrc";
      direnvrcContent = "echo foo";

      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        direnvrc = direnvrcContent;
      };
    in
    [
      (isDirectory (getDotdir wrapper))
      (isFile direnvrcFile)
      (fileContains direnvrcFile direnvrcContent)
    ];
}
