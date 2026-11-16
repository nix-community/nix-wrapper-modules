{
  config,
  pkgs,
  wlib,
  lib,
  ...
}:
{
  config.specMods =
    {
      parentSpec ? null,
      ...
    }:
    {
      _file = ./module.nix;
      options.pluginDeps = lib.mkOption {
        default = parentSpec.pluginDeps or "startup";
        type = lib.types.enum [
          false
          "startup"
          "lazy"
        ];
        description = ''
          plugins in nixpkgs sometimes have extra plugin dependencies added to
          `.dependencies` attribute. By default they will be added at startup.
        '';
      };
      options.autoconfig = lib.mkOption {
        type = lib.types.bool;
        default = parentSpec.autoconfig or true;
        description = ''
          plugins in nixpkgs sometimes have extra lua config added to
          `.passthru.initLua` attribute for compatibility.

          They will be ran before the nix-provided configuration for their associated plugin, if any
        '';
      };
      options.runtimeDeps = lib.mkOption {
        type = lib.types.enum [
          false
          "prefix"
          "suffix"
        ];
        default = parentSpec.runtimeDeps or "suffix";
        description = ''
          plugins in nixpkgs sometimes have extra dependencies added to
          `.runtimeDeps` attribute. By default they will be appended to the path,
        '';
      };
      options.collateGrammars = lib.mkOption {
        type = lib.types.bool;
        default = parentSpec.collateGrammars or true;
        description = ''
          If this plugin, or any of its dependencies from pluginDeps option,
          are a treesitter grammar passed through `nvim-treesitter.grammarToPlugin`,
          it will be collected into a single treesitter grammar plugin.

          This gives a nice boost in startup time.
        '';
      };
      options.propagateLuaDeps = lib.mkOption {
        type = lib.types.bool;
        default = parentSpec.propagateLuaDeps or true;
        description = ''
          Neovim plugins in nixpkgs sometimes are built as lua packages, and these sometimes have their own dependencies.

          The default value of `true` will include these on the `LUA_PATH` and `LUA_CPATH` for you automatically.

          Most users will wish this to remain `true`.
        '';
      };
    };
  config.prefixVar =
    let
      autodeps = config.specCollect (
        acc: v: acc ++ lib.optionals (v.runtimeDeps or false == "prefix") (v.data.runtimeDeps or [ ])
      ) [ ];
      isPrefixedRuby =
        config.hosts.ruby.nvim-host.enable or false && config.hosts.ruby.nvim-host.prefixRuby or false;
      isPrefixedNode =
        config.hosts.node.nvim-host.enable or false && config.hosts.node.nvim-host.prefixNode or false;
    in
    lib.mkIf (autodeps != [ ] || isPrefixedRuby || isPrefixedNode) (
      lib.mkOrder 1510 (
        lib.optional (autodeps != [ ]) {
          name = "NIXPKGS_AUTODEPS_PREFIX";
          data = [
            "PATH"
            ":"
            "${lib.makeBinPath autodeps}"
          ];
        }
        ++ lib.optional isPrefixedRuby {
          name = "RUBY_HOST_PATH_ADDITIONS";
          data = [
            "PATH"
            ":"
            "${config.hosts.ruby.wrapper}/bin"
          ];
        }
        ++ lib.optional isPrefixedNode {
          name = "NODE_HOST_PATH_ADDITIONS";
          data = [
            "PATH"
            ":"
            "${pkgs.nodejs}/bin"
          ];
        }
      )
    );
  config.suffixVar =
    let
      autodeps = config.specCollect (
        acc: v: acc ++ lib.optionals (v.runtimeDeps or false == "suffix") (v.data.runtimeDeps or [ ])
      ) [ ];
      isSuffixedRuby =
        config.hosts.ruby.nvim-host.enable or false && !(config.hosts.ruby.nvim-host.prefixRuby or true);
      isSuffixedNode =
        config.hosts.node.nvim-host.enable or false && !(config.hosts.node.nvim-host.prefixNode or true);
      collectedLuaPlugins = config.specCollect (
        acc: v:
        acc ++ lib.optional (v.propagateLuaDeps or true && v.data.requiredLuaModules or [ ] != [ ]) v.data
      ) [ ];
      partitionedLuaModules = builtins.partition (
        p:
        p.luaModule.LuaPathSearchPaths or null == config.package.lua.LuaPathSearchPaths or [ ]
        && p.luaModule.LuaCPathSearchPaths or null == config.package.lua.LuaCPathSearchPaths or [ ]
      ) collectedLuaPlugins;
      toIndividualLuaPaths =
        isC:
        builtins.concatMap (
          v:
          let
            gen = v.luaModule.pkgs.luaLib.${if isC then "genLuaCPathAbsStr" else "genLuaPathAbsStr"} or null;
          in
          if gen != null then map (lm: gen lm) v.requiredLuaModules else [ ]
        );
      otherLuaPathAdditions =
        if
          config.package.lua.LuaPathSearchPaths or [ ] == pkgs.neovim-unwrapped.lua.LuaPathSearchPaths or null
          &&
            config.package.lua.LuaCPathSearchPaths or [ ] == pkgs.neovim-unwrapped.lua.LuaCPathSearchPaths
              or null
        then
          # if we can use our neovim's lua for making the env for the ones from nixpkgs too, we did that already.
          {
            lua = toIndividualLuaPaths false partitionedLuaModules.wrong;
            c = toIndividualLuaPaths true partitionedLuaModules.wrong;
          }
        else
          # If we could not use the neovim's lua for making the env for the ones from nixpkgs too,
          # we will split those and combine the ones we can
          lib.pipe partitionedLuaModules.wrong [
            (builtins.partition (
              p:
              p.luaModule.LuaPathSearchPaths or [ ] == pkgs.neovim-unwrapped.lua.LuaPathSearchPaths or null
              && p.luaModule.LuaCPathSearchPaths or [ ] == pkgs.neovim-unwrapped.lua.LuaCPathSearchPaths or null
            ))
            ({ right, wrong }: {
              # make an env out of the ones from nixpkgs together
              fromnixpkgs =
                let
                  inherit (pkgs.neovim-unwrapped.lua) withPackages;
                  inherit (pkgs.neovim-unwrapped.lua.pkgs.luaLib) genLuaPathAbsStr genLuaCPathAbsStr;
                  env = withPackages (lp: right);
                in
                if right == [ ] then
                  { }
                else
                  {
                    lua = [ (genLuaPathAbsStr env) ];
                    c = [ (genLuaCPathAbsStr env) ];
                  };
              # otherwise fall back to individual
              other = {
                lua = toIndividualLuaPaths false wrong;
                c = toIndividualLuaPaths true wrong;
              };
            })
            ({ fromnixpkgs, other }: {
              lua = fromnixpkgs.lua or [ ] ++ other.lua or [ ];
              c = fromnixpkgs.c or [ ] ++ other.c or [ ];
            })
          ];
      luaEnv = (config.package.lua.withPackages or pkgs.luajit.withPackages) (
        lp:
        config.settings.nvim_lua_env lp
        ++ builtins.concatMap (v: v.requiredLuaModules) partitionedLuaModules.right
      );
      NVIM_LUA_PATH =
        ((config.package.lua or pkgs.luajit).pkgs.luaLib.genLuaPathAbsStr luaEnv)
        + lib.optionalString (partitionedLuaModules.wrong != [ ] && otherLuaPathAdditions.lua != [ ]) (
          ";" + builtins.concatStringsSep ";" otherLuaPathAdditions.lua
        );
      NVIM_LUA_CPATH =
        ((config.package.lua or pkgs.luajit).pkgs.luaLib.genLuaCPathAbsStr luaEnv)
        + lib.optionalString (partitionedLuaModules.wrong != [ ] && otherLuaPathAdditions.c != [ ]) (
          ";" + builtins.concatStringsSep ";" otherLuaPathAdditions.c
        );
    in
    lib.mkOrder 1510 (
      lib.optional (autodeps != [ ]) {
        name = "NIXPKGS_AUTODEPS_PREFIX";
        data = [
          "PATH"
          ":"
          "${lib.makeBinPath autodeps}"
        ];
      }
      ++ lib.optional isSuffixedRuby {
        name = "RUBY_HOST_PATH_ADDITIONS";
        data = [
          "PATH"
          ":"
          "${config.hosts.ruby.wrapper}/bin"
        ];
      }
      ++ lib.optional isSuffixedNode {
        name = "NODE_HOST_PATH_ADDITIONS";
        data = [
          "PATH"
          ":"
          "${pkgs.nodejs}/bin"
        ];
      }
      ++ [
        {
          name = "NIX_PROPAGATED_LUA_PATH";
          data = [
            "LUA_PATH"
            ";"
            NVIM_LUA_PATH
          ];
        }
        {
          name = "NIX_PROPAGATED_LUA_CPATH";
          data = [
            "LUA_CPATH"
            ";"
            NVIM_LUA_CPATH
          ];
        }
      ]
    );
  config.specMaps = lib.mkOrder 490 [
    {
      name = "NIXPKGS_PLUGIN_DEPS";
      data =
        # [ { name, type, value } ... ]
        list:
        let
          getPluginDeps =
            let
              getPluginDeps' =
                first: plugin:
                (if !first then [ plugin ] else [ ])
                ++ builtins.concatLists (map (getPluginDeps' false) (plugin.dependencies or [ ]));
            in
            getPluginDeps' true;
          pluginsPartitioned = lib.pipe list [
            (lib.filter (v: v.value.pluginDeps or false != false && v.value.data or null != null))
            (lib.partition (v: v.value.pluginDeps == "startup"))
          ];
          defaultspec = {
            name = null;
            pname = null;
            type = "lua";
            enable = true;
            config = null;
            info = { };
            before = [ ];
            after = [ ];
          };
          opt = lib.concatMap (
            v:
            map (data: {
              name = "pluginDepsLazy";
              type = "spec";
              value =
                (v.value or { })
                // {
                  lazy = true;
                  inherit data;
                }
                // defaultspec;
            }) (getPluginDeps v.value.data)
          ) pluginsPartitioned.wrong;
          manual = builtins.filter (v: v != null) (map (v: v.value.data or null) (opt ++ list));
          start = lib.concatMap (
            v:
            builtins.filter (v: v != null) (
              map (
                data:
                if builtins.elem data manual then
                  null
                else
                  {
                    name = "pluginDepsEager";
                    type = "spec";
                    value =
                      (v.value or { })
                      // {
                        lazy = false;
                        inherit data;
                      }
                      // defaultspec;
                  }
              ) (getPluginDeps v.value.data)
            )
          ) pluginsPartitioned.right;
        in
        start ++ opt ++ list;
    }
    {
      name = "NIXPKGS_AUTOCONFIGURE";
      after = [ "NIXPKGS_PLUGIN_DEPS" ];
      data =
        list:
        lib.concatMap (
          v:
          lib.optional (v.value.data.passthru.initLua or null != null && v.value.autoconfig or false) {
            name = v.name;
            type = v.type;
            value = {
              data = null;
              enable = true;
              name = null;
              before = lib.optional (v.value.name or null != null) v.value.name;
              type = "lua";
              config = v.value.data.passthru.initLua;
            };
          }
          ++ [ v ]
        ) list;
    }
    {
      name = "COLLATE_TS_GRAMMARS";
      after = [
        "NIXPKGS_AUTOCONFIGURE"
        "NIXPKGS_PLUGIN_DEPS"
      ];
      data =
        list:
        lib.pipe list [
          (builtins.foldl'
            (
              acc: v:
              let
                isGram =
                  v.value.collateGrammars or false
                  && v.value.data or null != null
                  && (
                    v.value.data.passthru.isTreesitterGrammar or false == true
                    || v.value.data.passthru.isTreesitterQuery or false == true
                    || (
                      !builtins.isString v.value.data
                      &&
                        builtins.match "^vimplugin-(nvim-)?treesitter-(grammar|queries)-.*" (lib.getName v.value.data)
                        != null
                    )
                  );
              in
              {
                grams = acc.grams ++ lib.optional isGram v.value.data;
                specs =
                  acc.specs
                  ++ (
                    if isGram then
                      [
                        (
                          v
                          // {
                            value = v.value // {
                              data = null;
                            };
                          }
                        )
                      ]
                    else
                      [ v ]
                  );
              }
            )
            {
              grams = [ ];
              specs = [ ];
            }
          )
          (
            { grams, specs }:
            let
              name = "COLLATED_TS_GRAMMARS";
            in
            lib.optional (grams != [ ]) {
              inherit name;
              type = "spec";
              value = {
                inherit name;
                enable = true;
                data = pkgs.symlinkJoin {
                  inherit name;
                  paths = grams;
                };
              };
            }
            ++ specs
          )
        ];
    }
  ];
  config.hosts.python3 =
    {
      config,
      lib,
      wlib,
      pkgs,
      specCollect,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      options.withPackages = lib.mkOption {
        type = wlib.types.withPackagesType;
        default = pp: [ ];
      };
      config.package = pkgs.python3;
      config.overrides = [
        {
          name = "withPackages";
          data = (
            x:
            x.withPackages (
              pp:
              let
                collected = specCollect (
                  acc: v:
                  acc
                  ++ lib.optionals (builtins.isList (v.data.python3Dependencies or null)) v.data.python3Dependencies
                ) [ ];
              in
              collected ++ config.withPackages pp ++ [ pp.pynvim ]
            )
          );
        }
      ];
      config.unsetVar = [ "PYTHONPATH" ];
    };
  config.hosts.perl =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      config.nvim-host.enable = lib.mkDefault false;
      options.withPackages = lib.mkOption {
        type = wlib.types.withPackagesType;
        default = pp: [ ];
      };
      config.package = pkgs.perl;
      config.overrides = [
        {
          name = "withPackages";
          data = (
            x:
            x.withPackages (
              pp:
              config.withPackages pp
              ++ [
                pp.NeovimExt
                pp.Appcpanminus
              ]
            )
          );
        }
      ];
    };
  config.hosts.node =
    {
      config,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      config.package = pkgs.neovim-node-client or pkgs.nodePackages.neovim;
      options.nvim-host.prefixNode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Prepend the pkgs.nodejs binary to neovim's PATH, rather than appending it";
      };
      # NOTE: nvim runs the thing with `node vim.g.node_host_prog`, we can't wrap it
      # maybe we could replace the shebang with a wrapped node at some point?
      # You can wrap it for when it gets linked into ${placeholder "out"}/bin though
      config.nvim-host.var_path = config.wrapperPaths.input;
    };
  config.hosts.ruby =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      config.package = lib.makeOverridable pkgs.bundlerEnv {
        name = "neovim-ruby-host";
        postBuild = "ln -sf ${pkgs.ruby}/bin/* ${placeholder config.outputName}/bin";
        gemdir = config.gemdir;
      };
      options.gemdir = lib.mkOption {
        type = wlib.types.stringable;
        default = "${pkgs.path}/pkgs/applications/editors/neovim/ruby_provider";
        description = "The path to the ruby gem directory with the neovim gem as required by `pkgs.bundlerEnv`";
      };
      options.nvim-host.prefixRuby = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Prepend the wrapped ruby binary to neovim's PATH, rather than appending it";
      };
      config.exePath = "bin/neovim-ruby-host";
      config.binName = "neovim-ruby-host";
    };
  config.env.GEM_HOME = lib.mkIf (config.hosts.ruby.nvim-host.enable or false
  ) "${config.hosts.ruby.package}/${config.hosts.ruby.package.ruby.gemPath or pkgs.ruby.gemPath}";
  config.hosts.neovide =
    {
      lib,
      wlib,
      pkgs,
      ...
    }:
    {
      imports = [ wlib.modules.default ];
      config.nvim-host.enable = lib.mkDefault false;
      config.package = pkgs.neovide;
      config.nvim-host.flags."--neovim-bin" = config.wrapperPaths.placeholder;
    };
}
