{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    ask = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Ask for confirmation before applying supported operations";
    };

    nom = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      internal = true;
    };

    rom = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use rom formatting for nix build output";
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = ''
        Preferred path/reference to a directory containing your flake.nix used by NH
        when running flake-based commands
      '';
    };

    searchChannel = lib.mkOption {
      type = lib.types.str;
      default = "unstable";
      description = ''
        Default Nixpkgs channel used by nh search packages and nh search operations
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Additional configuration for NH. Attribute names are prefixed with `NH_` when
        converted to environment variables. Built-in options take precedence over any
        attributes with conflicting names.
      '';
    };
  };

  config = {
    rom = lib.mkIf (config.nom != null) (
      lib.warn "nix-wrapper-modules nh: config.nom is deprecated, please use config.rom instead." config.nom
    );
    package = pkgs.nh;

    env =
      lib.mapAttrs' (
        name: value:
        lib.nameValuePair "NH_${name}" {
          data = value;
          esc-fn = toString;
        }
      ) config.extraConfig
      // {
        "NH_ASK" = {
          data = toString config.ask;
          esc-fn = toString;
        };
        ${
          if lib.strings.versionAtLeast (config.package.version or "4.5.0") "4.5.0" then
            "NH_ROM"
          else
            "NH_NOM"
        } =
          {
            data = toString config.rom;
            esc-fn = toString;
          };
        "NH_FLAKE" = {
          data = "${config.flake}";
          esc-fn = toString;
        };
        "NH_SEARCH_CHANNEL" = {
          data = "${config.searchChannel}";
          esc-fn = toString;
        };
      };

    meta.maintainers = [ wlib.maintainers.nakibrayane ];
  };
}
