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
    nix-jetbrains-plugins = lib.mkOption {
      type = lib.types.attrs;
      description = ''
        Nix JetBrains Plugins

        https://github.com/nix-community/nix-jetbrains-plugins

        You can obtain it as a flake input or by using non-flake input pinners
        such as Npins and Nixtamal.
      '';
    };

    jetbrainsIDE = lib.mkOption {
      type = lib.types.package;
      description = ''
        The JetBrains IDE package to use.

        Check the supported IDEs in Nix JetBrains Plugins docs.
      '';
    };

    plugins = {
      ideavim = {
        enable = lib.mkEnableOption "the IdeaVim plugin";
        ideavimrc = lib.mkOption {
          type = wlib.types.file {
            path = lib.mkOptionDefault config.constructFiles.ideavimrc.path;
          };
          description = ''
            The IdeaVim config file.
          '';
        };
      };

      extraPlugins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          A list of JetBrains plugin IDs to install.
        '';
      };

      applyPluginOverrides = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to apply plugin overrides.

          Set this to `false` to disable all plugin overrides, including the
          built-in overrides provided by Nix JetBrains Plugins and any overrides
          specified via `extraOverrides`.
        '';
      };

      dontOverride = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          A list of plugin IDs for which overrides from Nix JetBrains Plugins
          should not be applied.
        '';
      };

      extraOverrides = lib.mkOption {
        type = lib.types.attrsOf (lib.types.functionTo lib.types.package);
        default = { };
        description = ''
          A set of additional overrides to apply on top of the default
          overrides provided by Nix JetBrains Plugins.

          The items must be function that take a plugin derivation and return a
          modified derivation.
        '';
      };
    };
  };

  config.constructFiles.ideavimrc = lib.mkIf config.plugins.ideavim.enable {
    relPath = "ideavimrc";
    content = config.plugins.ideavim.ideavimrc.content;
  };

  config.package =
    let
      pluginIDs =
        config.plugins.extraPlugins
        ++ (
          if config.plugins.ideavim.enable then
            [
              "IdeaVIM"
            ]
          else
            [ ]
        );
      plugins = config.nix-jetbrains-plugins.lib.pluginsForIdeWith {
        inherit (config.plugins) applyPluginOverrides dontOverride extraOverrides;
      } pkgs config.jetbrainsIDE pluginIDs;

      ideWithPlugins = pkgs.jetbrains.plugins.addPlugins config.jetbrainsIDE (lib.attrValues plugins);
    in
    ideWithPlugins;

  config.env = lib.mkIf config.plugins.ideavim.enable {
    IDEA_VIM_CUSTOM_VIMRC = config.constructFiles.ideavimrc.path;
  };

  meta.maintainers = [ wlib.maintainers.ameer ];
}
