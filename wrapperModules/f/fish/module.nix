{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    attrValues
    concatMapStringsSep
    concatStringsSep
    escapeShellArg
    foldl'
    mapAttrsToList
    literalExpression
    mkDefault
    mkOption
    mkOptionDefault
    optionalString
    partition
    pipe
    splitString
    types
    ;

  cfg = config;
  split = wlib.makeWrapper.splitDal (wlib.makeWrapper.aggregateSingleOptionSet { inherit config; });

  abbreviationModule =
    { name, ... }:
    {
      options = {
        word = mkOption {
          type = types.str;
          default = name;
          description = "The word to be replaced";
        };
        expansion = mkOption {
          type = types.str;
          description = "The expansion to replace the word with";
        };
        position = mkOption {
          type = types.enum [
            "anywhere"
            "command"
          ];
          default = "command";
          description = ''
            The scope of the abbreviation.

            "anywhere": The abbreviation may expand anywhere in the command line

            "command": The abbreviation would only expand if it is positioned as a command
          '';
        };
        regex = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Special regex to expand instead of a word";
        };
        command = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The abbreviation will only expand if it is used as an argument to this command";
        };
        function = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "When the abbreviation matches, this function will be called with the matching token as an argument";
        };
        cursor = mkOption {
          type = types.either types.bool types.str;
          default = false;
          description = "The cursor is moved to the first occurrence of this in the expansion, or to \"%\" if set to true";
        };
      };
    };
  completionModule =
    { name, config, ... }:
    {
      config.path = mkOptionDefault (pkgs.writeText name config.content);
      options.command = mkOption {
        type = types.str;
        default = name;
        description = "The command to apply the completion for";
      };
    };
  pluginModule = {
    options = {
      src = mkOption {
        type = types.package;
        description = "The package which contains the plugin";
      };
      configDirs = mkOption {
        type = types.listOf types.str;
        default = cfg.pluginConfigDirs;
        description = "The directories which will be checked for config files";
      };
      completionDirs = mkOption {
        type = types.listOf types.str;
        default = cfg.pluginCompletionDirs;
        description = "The directories which will be checked for completion files";
      };
    };
  };
in
{
  imports = [
    wlib.modules.symlinkScript
    wlib.modules.constructFiles
    (
      (import wlib.modules.makeWrapper)
      // {
        excluded_options.wrapperFunction = true;
        excluded_options.top.wrapperImplementation = true;
      }
    )
  ];
  options = {
    wrapperVariants = mkOption {
      type = types.attrsOf (
        types.submoduleWith {
          modules = [
            (
              { name, ... }:
              {
                _file = wlib.modules.makeWrapper;
                config.mirror = lib.mkOverride 1400 false;
                config.package = lib.mkOverride 1400 (pkgs.${name} or pkgs.hello);
              }
            )
          ];
        }
      );
    };
    configFile = mkOption {
      type = wlib.types.file {
        path = mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default = {
        content = "";
        path = config.constructFiles.generatedConfig.path;
      };
      description = ''
        The main fish configuration file.

        Provide either `.content` to inline shell configuration or `.path` to reference an external file. 
        It is sourced by fish using `--init-command`.
      '';
    };
    abbreviations = mkOption {
      type = types.attrsOf (wlib.types.spec abbreviationModule);
      default = { };
      description = "Abbreviations to be included in the shell";
      example = literalExpression ''
        {
          lshome = "ls ~/";
          find-extension = {
            word = "ext";
            expansion = "~/ -name \"*.%\"";
            command = "find";
            cursor = true;
          };
          please = {
            expansion = "sudo";
            position = "command";
          };
        }
      '';
    };
    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Aliases to be included in the shell";
      example = {
        ls = "ls -a";
        ll = "ls -l";
      };
    };
    completionFiles = mkOption {
      type = types.attrsOf (wlib.types.file completionModule);
      default = { };
      description = "Completions to be included in the shell";
    };
    plugins = mkOption {
      type = types.listOf (wlib.types.spec pluginModule);
      default = [ ];
      description = "List of fish plugins to install";
      example = literalExpression ''
        [
          pkgs.fishPlugins.hydro
          {
            src = pkgs.fishPlugins.fzf-fish;
            configDirs = [ "share/fish/vendor_conf.d" ];
            completionDirs = [ "completions" ];
          }
        ]
      '';
    };
    pluginConfigDirs = mkOption {
      type = types.listOf types.str;
      default = [
        "share/fish/vendor_functions.d"
        "etc/fish/functions"
        "share/fish/vendor_conf.d"
        "etc/fish/conf.d"
      ];
      description = "The default directories to check for configs in plugins";
    };
    pluginCompletionDirs = mkOption {
      type = types.listOf types.str;
      default = [
        "share/fish/vendor_completions.d"
        "share/fish/completions"
      ];
      description = "The default directories to check for completion files in plugins";
    };
  };

  config.package = mkDefault pkgs.fish;
  config.passthru.shellPath = config.wrapperPaths.relPath;

  config.buildCommand.completionFiles.data = optionalString (cfg.completionFiles != [ ]) ''
    mkdir -p ${placeholder config.outputName}/completions
    ${concatStringsSep "\n" (
      mapAttrsToList (
        _: c: "cp ${c.path} ${placeholder config.outputName}/completions/${c.command}"
      ) cfg.completionFiles
    )}
  '';

  config.flags = {
    "--no-config" = mkDefault true;
    "--init-command" = {
      sep = "=";
      data = [
        "source ${config.constructFiles.generatedConfig.path}"
      ];
    };
  };

  config.constructFiles.generatedConfig = {
    relPath = "${config.binName}-config.fish";
    builder =
      let
        startSection = ''
          if set -q __wrapped_fish_sourced
            return
          end
          set -g __wrapped_fish_sourced 1
          fish_add_path --path ${dirOf config.wrapperPaths.placeholder}
        '';

        wrapcmd = partial: "echo ${escapeShellArg partial} >> \"$2\"";
        wrapperBuild = pipe split.other [
          (wlib.dag.unwrapSort "makeWrapper")
          (builtins.concatMap (
            v:
            let
              esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
            in
            if v.type or null == "unsetVar" then
              [ (wrapcmd "set -e ${esc-fn v.data}") ]
            else if v.type or null == "env" then
              [ (wrapcmd "wrapperSetEnv ${esc-fn v.attr-name} ${esc-fn v.data}") ]
            else if v.type or null == "envDefault" then
              [ (wrapcmd "wrapperSetEnvDefault ${esc-fn v.attr-name} ${esc-fn v.data}") ]
            else if v.type or null == "prefixVar" then
              let
                env = builtins.elemAt v.data 0;
                sep = builtins.elemAt v.data 1;
                val = builtins.elemAt v.data 2;
                vals = splitString sep val;
              in
              [
                (wrapcmd "wrapperPrefixEnv ${
                  concatMapStringsSep " " esc-fn (
                    [
                      env
                    ]
                    ++ vals
                  )
                }")
              ]
            else if v.type or null == "suffixVar" then
              let
                env = builtins.elemAt v.data 0;
                sep = builtins.elemAt v.data 1;
                val = builtins.elemAt v.data 2;
                vals = splitString sep val;
              in
              [
                (wrapcmd "wrapperSuffixEnv ${
                  concatMapStringsSep " " esc-fn (
                    [
                      env
                    ]
                    ++ vals
                  )
                }")
              ]
            else if v.type or null == "prefixContent" then
              let
                env = builtins.elemAt v.data 0;
                val = builtins.elemAt v.data 2;
                cmd = "wrapperPrefixEnv ${esc-fn env} ";
              in
              [ ''echo ${escapeShellArg cmd}"$(cat ${esc-fn val})" >> "$2"'' ]
            else if v.type or null == "suffixContent" then
              let
                env = builtins.elemAt v.data 0;
                val = builtins.elemAt v.data 2;
                cmd = "wrapperSuffixEnv ${esc-fn env} ";
              in
              [ ''echo ${escapeShellArg cmd}"$(cat ${esc-fn val})" >> "$2"'' ]
            else if v.type or null == "chdir" then
              [ (wrapcmd "cd ${esc-fn v.data}") ]
            else if v.type or null == "runShell" then
              [ (wrapcmd v.data) ]
            else
              [ ]
          ))
          (builtins.concatStringsSep "\n")
        ];

        wrapperInit =
          let
            setvarfunc = /* fish */ ''
              function wrapperSetEnv -a env val
                set -gx $env $val
              end
            '';
            setvardefaultfunc = /* fish */ ''
              function wrapperSetEnvDefault -a env val
                if not set -q $env
                  set -gx $env $val
                end
              end
            '';
            prefixvarfunc = /* fish */ ''
              function wrapperPrefixEnv -a env
                for val in $argv[2..-1]
                  set -pgx $env $val
                end
              end
            '';
            suffixvarfunc = /* fish */ ''
              function wrapperSuffixEnv -a env
                for val in $argv[2..-1]
                  set -agx $env $val
                end
              end
            '';
          in
          builtins.concatStringsSep "\n" (
            lib.optional (config.env or { } != { }) setvarfunc
            ++ lib.optional (config.envDefault or { } != { }) setvardefaultfunc
            ++ lib.optional (config.prefixVar or [ ] != [ ] || config.prefixContent or [ ] != [ ]) prefixvarfunc
            ++ lib.optional (config.suffixVar or [ ] != [ ] || config.suffixContent or [ ] != [ ]) suffixvarfunc
          );

        # make the main bin/fish wrapper binary with the arg wrapper items
        wrapperTeardown =
          let
            args =
              lib.optional (config.env or { } != { }) "wrapperSetEnv"
              ++ lib.optional (config.envDefault or { } != { }) "wrapperSetEnvDefault"
              ++ lib.optional (
                config.prefixVar or [ ] != [ ] || config.prefixContent or [ ] != [ ]
              ) "wrapperPrefixEnv"
              ++ lib.optional (
                config.suffixVar or [ ] != [ ] || config.suffixContent or [ ] != [ ]
              ) "wrapperSuffixEnv";
          in
          optionalString (args != [ ]) "functions -e ${builtins.concatStringsSep " " args}";
      in
      builtins.concatStringsSep "\n" [
        (wrapcmd startSection)
        (wrapcmd wrapperInit)
        wrapperBuild
        (wrapcmd wrapperTeardown)
        ''cat "$1" >> "$2"''
      ];
    content =
      let
        # The plugins with the default config and completion directories will be sourced in a shell loop
        # and the others will be sourced individually
        configurationPlugins = partition (p: p.configDirs == cfg.pluginConfigDirs) cfg.plugins;
        completionPlugins = partition (p: p.completionDirs == cfg.pluginCompletionDirs) cfg.plugins;

        mapPluginsToString =
          {
            plugins,
            dirList,
            functor,
            multiple ? true,
          }:
          let
            pluginLines =
              if (builtins.isFunction dirList) then
                map (plugin: map functor (dirList plugin)) plugins
              else
                map functor dirList;
            pluginsToString = plugins: toString (map (p: p.src) plugins);
          in
          optionalString (plugins != [ ]) ''
            set plugin${optionalString multiple "_list"} ${pluginsToString plugins}
            ${optionalString multiple "for plugin_dir in $plugin_list"}
              ${concatStringsSep "\n  " pluginLines}
            ${optionalString multiple "end"}
            set -e plugin${optionalString multiple "_list"}
          '';

        pluginSources = mapPluginsToString {
          plugins = configurationPlugins.right;
          dirList = cfg.pluginConfigDirs;
          functor = dir: ''
            for plugin in $plugin_dir/${dir}/*.fish
              source $plugin
            end
          '';
        };
        pluginCompletions = mapPluginsToString {
          plugins = completionPlugins.right;
          dirList = cfg.pluginCompletionDirs;
          functor = dir: ''
            if test -d $plugin_dir/${dir}
              set -a fish_complete_path $plugin_dir/${dir}
            end
          '';
        };

        customPluginSources = mapPluginsToString {
          plugins = configurationPlugins.wrong;
          dirList = plugin: plugin.configDirs;
          multiple = false;
          functor = dir: ''
            for plugin in $plugin/${dir}/*.fish
              source $plugin
            end
          '';
        };
        customPluginCompletions = mapPluginsToString {
          plugins = completionPlugins.wrong;
          dirList = plugin: plugin.completionDirs;
          multiple = false;
          functor = dir: ''
            if test -d $plugin/${dir}
              set -a fish_complete_path $plugin/${dir}
            end
          '';
        };

        mkAbbrArg = attr: abbr: optionalString (abbr.${attr} != null) "--${attr} ${abbr.${attr}}";
        abbrArgs = [
          "position"
          "regex"
          "command"
          "function"
        ];

        mkCursorArg =
          abbr:
          optionalString (
            abbr.cursor != false
          ) "--set-cursor${optionalString (builtins.isString abbr.cursor) "=${abbr.cursor}"}";

        mkAbbrStr =
          abbr:
          (foldl' (acc: elem: acc + " " + (mkAbbrArg elem abbr)) "abbr --add ${mkCursorArg abbr}" abbrArgs)
          + " -- ${abbr.word}"
          + optionalString (abbr.function == null) " ${lib.escapeShellArg abbr.expansion}";

        abbrs = concatStringsSep "\n" (map mkAbbrStr (attrValues cfg.abbreviations));
        aliases = concatStringsSep "\n" (
          mapAttrsToList (name: value: "alias ${name}=\"${value}\"") cfg.shellAliases
        );

        completions = "set -a fish_complete_path ${placeholder config.outputName}/completions";
      in
      (concatStringsSep "\n" [
        pluginSources
        pluginCompletions
        customPluginSources
        customPluginCompletions
        "if status is-interactive"
        aliases
        abbrs
        completions
        "end"
        cfg.configFile.content
      ]);
  };

  config.buildCommand.makeWrapper =
    let
      wrapperEntry =
        let
          baseArgs = map escapeShellArg [
            config.wrapperPaths.input
            config.wrapperPaths.placeholder
          ];
          cliArgs = pipe split.args [
            (wlib.makeWrapper.fixArgs { sep = config.flagSeparator or null; })
            (
              { addFlag, appendFlag }:
              let
                mapArgs =
                  name:
                  lib.flip pipe [
                    (map (
                      v:
                      let
                        esc-fn = if v.esc-fn or null != null then v.esc-fn else config.escapingFunction;
                      in
                      if builtins.isList (v.data or null) then
                        map esc-fn v.data
                      else if v ? data && v.data or null != null then
                        esc-fn v.data
                      else
                        [ ]
                    ))
                    lib.flatten
                    (builtins.concatMap (v: [
                      "--${name}"
                      v
                    ]))
                  ];
              in
              mapArgs "add-flag" addFlag ++ mapArgs "append-flag" appendFlag
            )
          ];
          srcsetup = p: "source ${escapeShellArg "${p}/nix-support/setup-hook"}";
        in
        ''
          (
            OLD_OPTS="$(set +o)"
            ${srcsetup pkgs.dieHook}
            ${srcsetup pkgs.makeBinaryWrapper}
            eval "$OLD_OPTS"
            makeWrapper ${builtins.concatStringsSep " " (baseArgs ++ cliArgs)}
          )
        '';
    in
    wrapperEntry + "\n" + wlib.makeWrapper.wrapVariants { inherit config pkgs; };

  config.meta.maintainers = [ wlib.maintainers.ormoyo ];
  config.meta.platforms = lib.platforms.linux;
}
