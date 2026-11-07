{
  description = "Generates the website documentation for the nix-wrapper-modules repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs =
    { nixpkgs, self, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.platforms.all;
      wlib-flake =
        pkgs: if pkgs == null then import ./.. { inherit nixpkgs; } else import ./.. { inherit pkgs; };
      wlib-flake-nopkgs = removeAttrs (wlib-flake null) [
        "formatter"
        "devShells"
      ];
      wlib = wlib-flake-nopkgs.lib;
    in
    wlib-flake-nopkgs
    // {
      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          tlib = pkgs.callPackage ./test-lib.nix { inherit self; };

          # Load checks from ci/checks/ directory
          coreAndCiChecks = lib.pipe ./checks [
            builtins.readDir
            builtins.attrNames
            (builtins.filter (name: lib.hasSuffix ".nix" name))
            (map (n: {
              name = lib.removeSuffix ".nix" n;
              value = ./checks + "/${n}";
            }))
            builtins.listToAttrs
          ];

          checksFrom =
            prefix: attrset:
            let
              importModuleCheck =
                name: value:
                let
                  helper = prefix: name: value: {
                    name = "${prefix}-${name}";
                    inherit value;
                  };
                  result = pkgs.callPackage value { inherit self tlib; };
                in
                if result == null then
                  [ ]
                else if result ? outPath then
                  [ (helper prefix name result) ]
                else
                  lib.mapAttrsToList (helper "${prefix}-${name}") (lib.filterAttrs (_: v: v ? outPath) result);
            in
            lib.pipe attrset [
              (lib.mapAttrsToList importModuleCheck)
              builtins.concatLists
              builtins.listToAttrs
            ];
        in
        checksFrom "wlib" coreAndCiChecks
        // checksFrom "module" (wlib.checks.helper or { })
        // checksFrom "wrapperModule" (wlib.checks.wrapper or { })
      );
      formatter = forAllSystems (
        system: (wlib-flake nixpkgs.legacyPackages.${system}).formatter.${system}
      );
      devShells = forAllSystems (
        system: (wlib-flake nixpkgs.legacyPackages.${system}).devShells.${system}
      );
      packages = forAllSystems (system: {
        default = self.packages.${system}.docs.wrap { warningsAreErrors = true; };
        docs = wlib.evalPackage [
          ./docs
          {
            warningsAreErrors = lib.mkDefault false;
            pkgs = import nixpkgs {
              inherit system;
              config = {
                # note: we want the name
                # so that config.binName and config.package and config.exePath look nice in docs
                # Nothing should build. This is fine...
                allowUnfree = true;
                allowBroken = true;
                allowUnsupportedSystem = true;
              };
            };
          }
        ];
      });
    };
}
