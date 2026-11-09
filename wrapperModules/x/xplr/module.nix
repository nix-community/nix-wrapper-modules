{
  config,
  pkgs,
  lib,
  wlib,
  ...
}:
let
  luaType = wlib.types.structuredValueWith {
    typeName = "lua";
    extraValueTypes = lib.types.luaInline;
  };
  enabledDagOf = wlib.types.dagOf // {
    modules = [
      {
        options.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the value";
        };
      }
    ];
  };
  configDagOf = enabledDagOf // {
    modules = enabledDagOf.modules ++ [
      {
        options = {
          plugin = lib.mkOption {
            type = lib.types.nullOr wlib.types.stringable;
            default = null;
            description = "You can add plugins to the config entries directly instead of `config.plugins`";
          };
          opts = lib.mkOption {
            type = luaType;
            default = { };
            description = ''
              Can be received in `.data` with `local opts, name = ...`
            '';
          };
          type = lib.mkOption {
            type = lib.types.enum [
              "fnl"
              "lua"
            ];
            default = config.defaultConfigLang;
            description = "The language to be used within this config segment";
          };
        };
      }
    ];
  };
  initDal =
    if builtins.isString config.luaInit then
      config.luaInit
    else
      builtins.filter (v: v.enable) (wlib.dag.unwrapSort "xplr_init" config.luaInit);
  hasFnl = builtins.any (v: v.type == "fnl") initDal;
  basePluginDir = "${placeholder config.outputName}/${config.binName}-plugins";
in
{
  imports = [ wlib.modules.default ];
  options.lua = lib.mkOption {
    type = lib.types.package;
    default = pkgs.luajit;
    description = "The lua derivation used to evaluate the `luaEnv` option";
  };
  options.defaultConfigLang = lib.mkOption {
    type = lib.types.enum [
      "fnl"
      "lua"
    ];
    default = "lua";
    description = "The default config language to use for generated config segments. Does not affect the `luaInfo` option.";
  };
  options.luaEnv = lib.mkOption {
    type = wlib.types.withPackagesType;
    default = lp: [ ];
    description = ''
      extra lua packages to add to the lua environment for xplr

      value is to be a function from `config.lua.pkgs` to list

      `config.luaEnv = lp: [ lp.inspect ];`

      The result will be added to package.path and package.cpath
    '';
  };
  options.plugins = lib.mkOption {
    type = enabledDagOf wlib.types.stringable;
    default = { };
    description = ''
      Will be symlinked into a directory added to the `LUA_PATH` and `LUA_CPATH`

      The name of the plugin via `require` will be the dag name for the value.

      The name in `config.infopath` is not allowed (default `nix-info`)
    '';
  };
  options.luaInit = lib.mkOption {
    type = lib.types.either lib.types.str (configDagOf lib.types.lines);
    default = { };
    description = builtins.readFile ./luaInit-desc.md;
  };
  options.infopath = lib.mkOption {
    type = lib.types.str;
    default = "nix-info";
    description = ''
      The default require path for the result of the luaInfo option.
      Don't change this unless you have a really good reason to.
    '';
  };
  options.luaInfo = lib.mkOption {
    type = luaType;
    default = { };
    description = ''
      `luaInfo` is a Lua table that can hold arbitrary data you want to expose to your Lua environment.

      This table is automatically converted to Lua code and made available under `require "nix-info"`.

      `config.defaultConfigLang` does NOT affect this value.

      the name `nix-info` can be changed via `config.infopath` option
    '';
  };
  config.package = lib.mkDefault pkgs.xplr;
  config.constructFiles = {
    nixLuaInfo = {
      relPath = "${config.binName}-plugins/${config.infopath}.lua";
      content = /* lua */ ''
        return setmetatable(${lib.generators.toLua { } config.luaInfo}, {
          __call = function(self, default, ...)
            if select('#', ...) == 0 then return default end
            local tbl = self;
            for _, key in ipairs({...}) do
              if type(tbl) ~= "table" then return default end
              tbl = tbl[key]
            end
            return tbl
          end
        })
      '';
    };
    nixLuaInit = {
      relPath = "${config.binName}-rc.lua";
      content =
        let
          versionstr =
            if hasFnl then
              "(tset _G :version ${builtins.toJSON config.package.version})"
            else
              "version = ${builtins.toJSON config.package.version}";
          generatedConfig = lib.pipe initDal [
            (map (
              v:
              let
                lua = "(function(...) ${v.data} end)(${
                  lib.generators.toLua { } v.opts
                }, ${builtins.toJSON v.name})";
                fnl = ''((fn [...] ${v.data}) (lua "" ${builtins.toJSON "${lib.generators.toLua { } v.opts}"}) ${builtins.toJSON v.name})'';
              in
              if hasFnl then if v.type == "fnl" then fnl else ''(lua "" ${builtins.toJSON lua})'' else lua
            ))
            (builtins.concatStringsSep (if hasFnl then "\n" else ",\n"))
          ];

          nixInit = (
            if builtins.isString initDal then
              initDal
            else if hasFnl then
              /* fennel */ ''
                ((fn [hooks]
                   (fn add-hooks [res b]
                     (each [k vlist (pairs b)]
                       (local acc (. res k))
                       (if (not= (type acc) :table) (tset res k vlist)
                           (not= (type vlist) :table)
                           (error (.. "expected a list of hooks at " (tostring k)
                                      ", but got a " (type vlist)))
                           (let [n (length acc)]
                             (for [i 1 (length vlist)] (tset acc (+ n i) (. vlist i))))))
                     res)

                   (var result {})
                   (for [i 1 (select "#" ((or unpack table.unpack) hooks))]
                     (local h (. hooks i))
                     (when (= (type h) :table) (set result (add-hooks result h))))
                   result) [
                    ${generatedConfig}
                   ])''
            else
              /* lua */ ''
                return (function(hooks)
                  local function add_hooks(res, b)
                    for k, vlist in pairs(b) do
                      local acc = res[k]
                      if type(acc) ~= "table" then
                        res[k] = vlist
                      elseif type(vlist) ~= "table" then
                        error("expected a list of hooks at ".. tostring(k) ..", but got a " .. type(vlist))
                      else
                        local n = #acc
                        for i = 1, #vlist do
                          acc[n + i] = vlist[i]
                        end
                      end
                    end
                    return res
                  end
                  local result = {}
                  for i = 1, select('#', (unpack or table.unpack)(hooks)) do
                    local h = hooks[i]
                    if type(h) == "table" then
                      result = add_hooks(result, h)
                    end
                  end
                  return result
                end)({
                  ${generatedConfig}
                })''
          );
        in
        ''
          ${versionstr}
          ${nixInit}
        '';
      builder = ''
        { [ -e "$1" ] && cat "$1" || echo "$nixLuaInit"; }${
          if hasFnl then " | ${pkgs.luajitPackages.fennel}/bin/fennel --compile - " else " "
        }> "$2"
      '';
    };
  };
  config.buildCommand.linkXplrPlugins =
    let
      errORname =
        name:
        if name == config.infopath then
          "plugin name '${config.infopath}' already taken by luaInfo result. Change the name, or value of `config.infopath`"
        else if name == null then
          "name must be provided for a plugin!"
        else
          name;
      mkLinkCommand =
        name: plugin:
        "ln -sf ${lib.escapeShellArg plugin} ${lib.escapeShellArg "${basePluginDir}/${errORname name}"}";
      linkCommands = lib.pipe initDal [
        (v: if builtins.isString v then [ ] else v)
        (map (v: if v.plugin or null != null then v // { data = v.plugin; } else null))
        (builtins.filter (v: v != null))
        (dal: builtins.filter (v: v.enable) (wlib.dag.dagToDal config.plugins) ++ dal)
        (wlib.dag.unwrapSort "xplr_plugins")
        (map (v: mkLinkCommand v.name v.data))
        (builtins.concatStringsSep "\n")
      ];
    in
    /* bash */ ''
      mkdir -p ${lib.escapeShellArg basePluginDir}
      ${linkCommands}
    '';
  config.prefixVar =
    let
      withPackages = config.lua.withPackages or pkgs.luajit.withPackages;
      genLuaCPathAbsStr =
        config.lua.pkgs.luaLib.genLuaCPathAbsStr or pkgs.luajit.pkgs.luaLib.genLuaCPathAbsStr;
      genLuaPathAbsStr =
        config.lua.pkgs.luaLib.genLuaPathAbsStr or pkgs.luajit.pkgs.luaLib.genLuaPathAbsStr;
      luaEnv = withPackages config.luaEnv;
    in
    lib.mkIf ((config.luaEnv config.lua.pkgs) != [ ]) [
      {
        name = "GENERATED_LUA_PATH";
        data = [
          "LUA_PATH"
          ";"
          ("${basePluginDir}/?.lua;${basePluginDir}/?/init.lua;" + genLuaPathAbsStr luaEnv)
        ];
      }
      {
        name = "GENERATED_LUA_CPATH";
        data = [
          "LUA_CPATH"
          ";"
          ("${basePluginDir}/?.so;" + genLuaCPathAbsStr luaEnv)
        ];
      }
    ];
  config.addFlag = [
    {
      # use addFlag because it allows multiple -c args
      # and while config.flags values can be a list for that purpose,
      # the esc-fn option would be for all of them.
      name = "GENERATED_WRAPPER_LUA";
      data = [
        "-c"
        config.constructFiles.nixLuaInit.path
      ];
      esc-fn = lib.escapeShellArg;
    }
  ];
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
