{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  isLinkable = wlib.types.linkable.check;
in
{
  imports = [ wlib.modules.default ];

  options = {
    configFile = lib.mkOption {
      type = lib.types.either wlib.types.linkable lib.types.lines;
      default = "";
      description = ''
        The Hyprland configuration file.

        Provide either inlined configuration or reference an external file.
      '';
    };

    "hyprland.lua" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
        content =
          let
            getPluginPath =
              plugin: if lib.types.package.check plugin then "${plugin}/lib/lib${plugin.pname}.so" else plugin;

            pluginLoading =
              if config.plugins != [ ] then
                ''
                  hl.on("hyprland.start", function()
                  ${lib.concatMapStringsSep "\n" (
                    plugin: "  hl.exec_cmd(\"hyprctl plugin load ${getPluginPath plugin}\")"
                  ) config.plugins}
                  end)

                ''
              else
                "";

            luaDirsLoading =
              if config.lua.dirs != [ ] then
                let
                  toLua = lib.generators.toLua { };
                  toLuaPath = lib.flip lib.pipe [
                    (builtins.concatMap (v: [
                      "${toLua v} .. '/?.lua'"
                      "${toLua v} .. '/?/init.lua'"
                    ]))
                    (builtins.concatStringsSep " .. ';' .. ")
                  ];
                  toLuaCPath = lib.flip lib.pipe [
                    (map (v: "${toLua v} .. '/?.so'"))
                    (builtins.concatStringsSep " .. ';' .. ")
                  ];
                in
                ''
                  package.path = ${toLuaPath config.lua.dirs} .. ";" .. package.path;
                  package.cpath = ${toLuaCPath config.lua.dirs} .. ";" .. package.path;
                ''
              else
                "";

            luaPackagesLoading =
              if config.lua.packages config.lua.lua.pkgs != [ ] then
                let
                  luaEnv = config.lua.lua.withPackages config.lua.packages;
                  luaLib = config.lua.lua.pkgs.luaLib;
                in
                ''
                  package.path = ${builtins.toJSON (luaLib.genLuaPathAbsStr luaEnv)} .. ";" .. package.path;
                  package.cpath = ${builtins.toJSON (luaLib.genLuaCPathAbsStr luaEnv)} .. ";" .. package.cpath;
                ''
              else
                "";

            userConfigLoading = "dofile(\"${config.constructFiles.userConfig.path}\")";
          in
          pluginLoading + luaDirsLoading + luaPackagesLoading + userConfigLoading;
      };
      default = { };
      description = ''
        Hyprland configuration file.
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.package lib.types.path);
      default = [ ];
      description = ''
        Plugins to install and load alongside Hyprland.

        Make sure to guard your plugin configuration behind
        a check whether the plugin is loaded!
      '';
    };

    lua = {
      dirs = lib.mkOption {
        type = lib.types.listOf (
          lib.types.oneOf [
            lib.types.package
            lib.types.path
            lib.types.luaInline
          ]
        );
        default = [ ];
        description = ''
          Paths to add to the `package.path` and `package.cpath` to be called using `require`.
        '';
      };
      lua = lib.mkOption {
        type = lib.types.package;
        default = pkgs.lua5_5;
        description = ''
          The lua interpreter from nixpkgs `lua.packages` will get packages from.
        '';
      };
      packages = lib.mkOption {
        type = wlib.types.withPackagesType;
        default = lp: [ ];
        description = ''
          A function providing lua 5.5 packages from nixpkgs to add to the lua environment.
          It recieves the set of lua packages to choose from as it's argument.
        '';
      };
    };

    disableConfigValidation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When `true`, the wrapper will not verify the nix-provided config file.

        This is useful for debugging the output of the generated config file.

        It also allows you to pass an impure path via `config."hyprland.lua".path`,
        as nix no longer needs to know about this path at build time.
      '';
    };
  };

  config.package = lib.mkDefault pkgs.hyprland;
  config.passthru.providedSessions = config.package.providedSessions;

  config.flags."--config" = config."hyprland.lua".path;

  # NOTE: gives users a nice error message about invalid configs
  config.drv.installPhase = lib.mkIf (!config.disableConfigValidation) ''
    runHook preInstall
    export XDG_RUNTIME_DIR=$(mktemp -d)
    ${lib.getExe config.package} --verify-config -c "${config.constructFiles.generatedConfig.path}"
    runHook postInstall
  '';

  config.constructFiles.userConfig =
    let
      linkable = isLinkable config.configFile;
    in
    {
      content = lib.mkIf (!linkable) config.configFile;
      builder = lib.mkIf linkable ''ln -s ${config.configFile} "$2"'';
      relPath = "${config.binName}-user.lua";
    };
  config.constructFiles.generatedConfig = {
    content = config."hyprland.lua".content;
    relPath = "${config.binName}-config.lua";
  };

  config.wrapperImplementation = "binary";

  config.meta = {
    maintainers = [ wlib.maintainers.jonas-elhs ];
    platforms = lib.platforms.linux;
  };
}
