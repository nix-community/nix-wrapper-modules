{
  description = ''
    Uses flake-parts to set up the flake outputs:

    `wrappers`, `wrapperModules` and `packages.*.*`
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

      perSystem =
        { pkgs, ... }:
        {
          # wrappers.pkgs = pkgs; # choose a different `pkgs`
          wrappers.control_type = "exclude"; # | "build"  (default: "exclude")
          wrappers.packages = {
            hello = true; # <- set to true to exclude from being built into `packages.*.*` flake output
          };
        };
      flake.wrappers.hello = ./hello.nix;
      flake.wrappers.tmux =
        { wlib, pkgs, ... }:
        {
          imports = [ wlib.wrapperModules.tmux ];
          plugins = with pkgs.tmuxPlugins; [ onedark-theme ];
        };
    };
}
