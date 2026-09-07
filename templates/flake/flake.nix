{
  description = "Flake exporting a configured package using wlib.evalModule";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.wrappers.url = "github:nix-community/nix-wrapper-modules";
  inputs.wrappers.inputs.nixpkgs.follows = "nixpkgs";
  outputs =
    {
      self,
      nixpkgs,
      wrappers,
      ...
    }@inputs:
    let
      forAllSystems = with nixpkgs.lib; genAttrs platforms.all;
      module = ./module.nix;
      wrapper = wrappers.lib.evalModule module;
    in
    {
      overlays.default = final: prev: {
        ${wrapper.config.binName} = wrapper.config.wrap { pkgs = prev; };
      };
      wrapperModules.default = module;
      wrappers.default = wrapper.config;
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = wrapper.config.wrap { inherit pkgs; };
          hello-from-system = wrapper.config.wrap {
            inherit pkgs;
            greeting = "hello from ${pkgs.stdenv.hostPlatform.system}";
          };
        }
      );
    };
}
