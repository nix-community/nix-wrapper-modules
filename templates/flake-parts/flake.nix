{
  description = ''
    Uses flake-parts to set up the flake outputs:

    `wrappers.*`, `wrapperModules.*` and `packages.*.*`
  '';
  inputs.wrappers.url = "github:nix-community/nix-wrapper-modules";
  inputs.wrappers.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  outputs =
    {
      self,
      nixpkgs,
      wrappers,
      flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ wrappers.flakeModules.wrappers ];
      systems = nixpkgs.lib.platforms.all;
      flake.wrappers.default =
        {
          wlib,
          pkgs,
          lib,
          config,
          ...
        }:
        {
          imports = [ wlib.modules.default ];
          config.package = pkgs.hello;
        };
    };
}
