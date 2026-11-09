{
  lib,
  flake-parts-lib,
  config,
  ...
}:
let
  inherit (lib) types mkOption;
  file = ./parts.nix;
in
{
  _file = file;
  key = file;
  options.flake = mkOption {
    type = types.submoduleWith {
      modules = [
        (
          { options, ... }:
          {
            _file = file;
            key = file;
            options.wrappers = mkOption {
              type = types.lazyAttrsOf ((import ./lib { inherit lib; }).types.subWrapperModuleWith { });
              default = { };
              description = ''
                Submodule option for configuring and exporting wrapper modules!

                https://github.com/nix-community/nix-wrapper-modules
              '';
            };
            options.wrapperModules = mkOption {
              type = types.lazyAttrsOf types.deferredModule;
              readOnly = true;
              description = ''
                contains importable module forms of your wrappers output

                Read only. Modify `flake.wrappers` instead, this will reflect that option.

                https://github.com/nix-community/nix-wrapper-modules
              '';
            };
            config.wrapperModules = (types.lazyAttrsOf types.deferredModule).merge options.wrappers.loc options.wrappers.definitionsWithLocations;
          }
        )
      ];
    };
  };
  options.perSystem =
    let
      inherit (config.flake) wrappers;
    in
    flake-parts-lib.mkPerSystemOption (
      {
        pkgs,
        config,
        ...
      }:
      {
        _file = file;
        key = file;
        options.wrappers.pkgs = mkOption {
          type = types.pkgs;
          default = pkgs;
          description = ''
            The `pkgs` object used to build `outputs.wrappers` into packages
          '';
        };
        options.wrappers.control_type = mkOption {
          type = types.enum [
            "build"
            "exclude"
          ];
          default = "exclude";
          description = ''
            The behavior of `perSystem.wrappers.packages`

            `exclude` will cause true values in the set to exclude that package.
            `build` will cause only true values in the set to be built.
          '';
        };
        options.wrappers.packages = mkOption {
          type = types.attrsOf types.bool;
          default = { };
          description = ''
            A set of booleans indicating which packages should be built.

            Behavior of this option is determined by `perSystem.wrappers.control_type`
          '';
        };
        config.packages = lib.pipe wrappers [
          (
            v:
            let
              args = lib.filterAttrs (_: v: v) config.wrappers.packages;
            in
            if config.wrappers.control_type == "build" then
              builtins.intersectAttrs args wrappers
            else
              lib.filterAttrs (n: _: !args ? "${n}") wrappers
          )
          (builtins.mapAttrs (
            _: v:
            v.wrap {
              _file = file;
              inherit (config.wrappers) pkgs;
            }
          ))
        ];
      }
    );
}
