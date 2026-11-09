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
      type = lib.types.bool;
      default = true;
      description = "Use nix-output-monitor for Nix output";
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
        "NH_NOM" = {
          data = toString config.nom;
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
