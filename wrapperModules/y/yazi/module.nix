{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  tomlFmtType = wlib.types.structuredValueWith {
    nullable = false;
    typeName = "TOML";
  };
in
{
  imports = [ wlib.modules.default ];

  options.settings = {
    yazi = lib.mkOption {
      default = { };

      description = ''
        Content of yazi.toml file.
        See the configuration reference at <https://yazi-rs.github.io/docs/configuration/yazi>
      '';

      type = lib.types.submodule {
        freeformType = tomlFmtType;
        options = {
          mgr = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Manager settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#mgr>
            '';
            default = { };
          };

          preview = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Preview settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#preview>
            '';
            default = { };
          };

          opener = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Opener settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#opener>
            '';
            default = { };
          };

          open = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Open settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#open>
            '';
            default = { };
          };

          plugin = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Plugin settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#plugin>
            '';
            default = { };
          };

          input = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Input settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#input>
            '';
            default = { };
          };

          confirm = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Confirm settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#confirm>
            '';
            default = { };
          };

          pick = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Pick settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#pick>
            '';
            default = { };
          };

          which = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Which settings
              See <https://yazi-rs.github.io/docs/configuration/yazi#which>
            '';
            default = { };
          };

        };
      };
    };

    keymap = lib.mkOption {
      default = { };
      description = ''
        Content of keymap.toml file.
        See the configuration reference at <https://yazi-rs.github.io/docs/configuration/keymap>
      '';

      type = lib.types.submodule {
        freeformType = tomlFmtType;
        options = {
          mgr = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Keymap mgr settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#mgr>
            '';
            default = { };

          };

          tasks = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Keymap tasks settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#tasks>
            '';
            default = { };

          };

          spot = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Keymap spot settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#spot>
            '';
            default = { };

          };

          pick = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Keymap pick settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#pick>
            '';
            default = { };

          };

          input = lib.mkOption {
            type = tomlFmtType;
            description = ''
              Keymap input settings
              See <https://yazi-rs.github.io/docs/configuration/keymap#input>
            '';
            default = { };

          };

          confirm = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Keymap confirm settings
              See < https://yazi-rs.github.io/docs/configuration/keymap#confirm>
            '';
            default = { };

          };

          cmp = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Keymap cmp settings
              See < https://yazi-rs.github.io/docs/configuration/keymap#cmp>
            '';
            default = { };

          };

          help = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Keymap help settings
              See < https://yazi-rs.github.io/docs/configuration/keymap#help>
            '';
            default = { };

          };
        };
      };
    };

    theme = lib.mkOption {
      default = { };
      description = ''
        Content of theme.toml file.
        See the configuration reference at <https://yazi-rs.github.io/docs/configuration/theme>
      '';

      type = lib.types.submodule {
        freeformType = tomlFmtType;
        options = {
          flavor = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme flawor settings
              See < https://yazi-rs.github.io/docs/configuration/theme#flavor>
            '';
            default = { };
          };

          app = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme app settings
              See < https://yazi-rs.github.io/docs/configuration/theme#app>
            '';
            default = { };
          };

          mgr = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme mgr settings
              See < https://yazi-rs.github.io/docs/configuration/theme#mgr>
            '';
            default = { };

          };

          indicator = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme indicator settings
              See < https://yazi-rs.github.io/docs/configuration/theme#indicator>
            '';
            default = { };
          };

          tabs = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme tabs settings
              See < https://yazi-rs.github.io/docs/configuration/theme#tabs>
            '';
            default = { };
          };

          mode = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme mode settings
              See < https://yazi-rs.github.io/docs/configuration/theme#mode>
            '';
            default = { };
          };

          status = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme status settings
              See < https://yazi-rs.github.io/docs/configuration/theme#status>
            '';
            default = { };
          };

          which = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme which settings
              See < https://yazi-rs.github.io/docs/configuration/theme#which>
            '';
            default = { };
          };

          confirm = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme confirm settings
              See < https://yazi-rs.github.io/docs/configuration/theme#confirm>
            '';
            default = { };
          };

          spot = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme spot settings
              See < https://yazi-rs.github.io/docs/configuration/theme#spot>
            '';
            default = { };
          };

          notify = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme notify settings
              See < https://yazi-rs.github.io/docs/configuration/theme#notify>
            '';
            default = { };
          };

          pick = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme pick settings
              See < https://yazi-rs.github.io/docs/configuration/theme#pick>
            '';
            default = { };
          };

          input = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme input settings
              See < https://yazi-rs.github.io/docs/configuration/theme#input>
            '';
            default = { };

          };

          cmp = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme cmp settings
              See < https://yazi-rs.github.io/docs/configuration/theme#cmp>
            '';
            default = { };
          };

          tasks = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme tasks settings
              See < https://yazi-rs.github.io/docs/configuration/theme#tasks>
            '';
            default = { };
          };

          help = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme help settings
              See < https://yazi-rs.github.io/docs/configuration/theme#help>
            '';
            default = { };
          };

          filetype = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme filetype settings
              See < https://yazi-rs.github.io/docs/configuration/theme#filetype>
            '';
            default = { };
          };

          icon = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Theme icon settings
              See < https://yazi-rs.github.io/docs/configuration/theme#icon>
            '';
            default = { };
          };
        };
      };
    };

    vfs = lib.mkOption {
      default = { };
      description = ''
        Content of the vfs.toml file.
        See configuration reference at <https://yazi-rs.github.io/docs/configuration/vfs>
      '';
      type = lib.types.submodule {
        freeformType = tomlFmtType;
        options = {
          services = lib.mkOption {
            type = tomlFmtType;
            description = ''
               Vfs settings
              See < https://yazi-rs.github.io/docs/configuration/vfs>
            '';
            default = { };
          };
        };
      };
    };

    package = lib.mkOption {
      default = { };
      description = ''
        Content of the package.toml file.
        See configuration reference at <https://yazi-rs.github.io/docs/cli/#pm>
      '';

      type = lib.types.submodule {
        freeformType = tomlFmtType;
        options = {
          plugin = lib.mkOption {
            description = ''
              Set for plugin settings and paths.
              See configuration reference at <https://yazi-rs.github.io/docs/cli/#pm>
            '';
            default = { };
            type = lib.types.submodule {
              freeformType = tomlFmtType;
              options.deps = lib.mkOption {
                type = lib.types.listOf tomlFmtType;
                default = [ ];
                description = ''
                  List of plugins and dependencies.
                    See configuration reference at <https://yazi-rs.github.io/docs/cli/#pm>
                '';
              };
            };
          };
        };
      };
    };
  };
  options.initLua = lib.mkOption {
    default = null;
    description = ''
      Content of the init.lua file.
    '';
    type = lib.types.nullOr (lib.types.either lib.types.path lib.types.lines);
    example = lib.literalMD ''
      ```lua
      require("session"):setup {
        sync_yanked = true,
      }
      ```
    '';
  };
  options.generatedConfig.output = lib.mkOption {
    type = lib.types.str;
    default = config.outputName;
    description = ''
      The derivation output for the config generated by this wrapper module
    '';
  };
  options.generatedConfig.placeholder = lib.mkOption {
    type = lib.types.str;
    default = "${placeholder config.generatedConfig.output}/${config.binName}-config";
    readOnly = true;
    description = ''
      The placeholder accessible in the wrapper derivation build script for the config generated by this wrapper module
    '';
  };

  options.plugins = lib.mkOption {
    type = lib.types.attrsOf (lib.types.nullOr wlib.types.stringable);
    default = { };
    description = ''
      An attribute set of plugin names and their paths
    '';
    example = lib.literalMD ''
      ```nix
      with pkgs.yaziPlugins; {
        smart-enter = smart-enter;
        drag = inputs.drag;
        gvfs = inputs.gvfs-yazi;
        git = git;
        starship = starship;
        full-border = full-border;
      };
      ```
    '';
  };
  options.flavors = lib.mkOption {
    type = lib.types.attrsOf (lib.types.nullOr wlib.types.stringable);
    default = { };
    description = ''
      An attribute set of flavor names and their paths
    '';
  };
  config.buildCommand.makePluginsAndFlavors = {
    before = [ "constructFiles" ]; # <- by default constructFiles is the first of the 3 in modules.default
    data =
      let
        toLink =
          dir: n: v:
          lib.optionalString (v != null)
            "ln -s ${lib.escapeShellArg v} ${lib.escapeShellArg "${config.generatedConfig.placeholder}/${dir}/${n}.yazi"}";
      in
      ''
        mkdir -p ${lib.escapeShellArg "${config.generatedConfig.placeholder}/plugins"}
        mkdir -p ${lib.escapeShellArg "${config.generatedConfig.placeholder}/flavors"}
      ''
      + lib.concatMapAttrsStringSep "\n" (toLink "plugins") config.plugins
      + "\n"
      + lib.concatMapAttrsStringSep "\n" (toLink "flavors") config.flavors;
  };

  config.package = lib.mkDefault pkgs.yazi;
  config.env.YAZI_CONFIG_HOME = config.generatedConfig.placeholder;
  # make `finalpackage.generatedConfig` point to the generated config so it can be used from outside of the wrapper module
  config.passthru.generatedConfig = "${
    config.wrapper.${config.generatedConfig.output}
  }/${config.binName}-config";
  # using constructFiles instead of (pkgs.formats.toml {}).generate allows placeholders to refer to the final wrapper derivation in the options.
  config.constructFiles =
    (builtins.mapAttrs
      (n: v: {
        # generate the directory of toml files
        # use lib.mkOverride 0 to force the value to make sure they stay together
        relPath = lib.mkOverride 0 "${config.binName}-config/${n}.toml";
        output = lib.mkOverride 0 config.generatedConfig.output;
        content = builtins.toJSON v;
        # redefine builder to convert the result to toml.
        # This is how pkgs.format.toml works
        # https://github.com/NixOS/nixpkgs/blob/27298c9e6596851fe781e04e54704d705d91f38b/pkgs/pkgs-lib/formats.nix#L455-L477
        builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      })
      {
        yazi = config.settings.yazi;
        keymap = config.settings.keymap;
        theme = config.settings.theme;
        vfs = config.settings.vfs;
        package = config.settings.package;
      }
    )
    // {
      initlua = lib.mkIf (config.initLua != null) {
        relPath = "${config.binName}-config/init.lua";
        content =
          if builtins.isPath config.initLua then builtins.readFile config.initLua else config.initLua;
      };
    };
  config.meta.maintainers = [ wlib.maintainers.apetrovic6 ];
}
