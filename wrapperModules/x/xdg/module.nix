{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  types = lib.types;
  pathAsStr = types.coercedTo types.path builtins.toString types.str;
in
{
  imports = [ wlib.modules.default ];

  options = {
    baseDirs.enable = lib.mkEnableOption "management of XDG base directories";

    baseDirs.cacheHome = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/.cache";
      description = ''
        Absolute path to directory holding application caches.

        Sets `XDG_CACHE_HOME` for the user if `xdg.enable` is set `true`.
      '';
    };

    baseDirs.configHome = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/.config";
      description = ''
        Absolute path to directory holding application configurations.

        Sets `XDG_CONFIG_HOME` for the user if `xdg.enable` is set `true`.
      '';
    };

    baseDirs.dataHome = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/.local/share";
      description = ''
        Absolute path to directory holding application data.

        Sets `XDG_DATA_HOME` for the user if `xdg.enable` is set `true`.
      '';
    };

    baseDirs.stateHome = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/.local/state";
      description = ''
        Absolute path to directory holding application states.

        Sets `XDG_STATE_HOME` for the user if `xdg.enable` is set `true`.
      '';
    };

    userDirs.enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to manage {file}`$XDG_CONFIG_HOME/user-dirs.dirs`.

        The generated file is read-only.
      '';
    };

    userDirs.package = lib.mkPackageOption pkgs "xdg-user-dirs" { nullable = true; };

    # Well-known directory list from
    # https://gitlab.freedesktop.org/xdg/xdg-user-dirs/blob/master/man/user-dirs.dirs.xml

    userDirs.desktop = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/Desktop";
      description = "The Desktop directory.";
    };

    userDirs.documents = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/Documents";
      description = "The Documents directory.";
    };

    userDirs.download = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/Downloads";
      description = "The Downloads directory.";
    };

    userDirs.music = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/Music";
      description = "The Music directory.";
    };

    userDirs.pictures = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/Pictures";
      description = "The Pictures directory.";
    };

    userDirs.publicShare = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/Public";
      description = "The Public share directory.";
    };

    userDirs.templates = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/Templates";
      description = "The Templates directory.";
    };

    userDirs.videos = lib.mkOption {
      type = types.nullOr pathAsStr;
      default = "$HOME/Videos";
      description = "The Videos directory.";
    };

    userDirs.extraConfig = lib.mkOption {
      type = types.attrsOf (pathAsStr);
      default = { };
      defaultText = lib.literalExpression "{ }";
      example = lib.literalExpression ''
        {
          MISC = "$HOME/Misc";
        }
      '';
      description = ''
        Other user directories.

        The key ‘MISC’ corresponds to the user-dirs entry ‘XDG_MISC_DIR’.
      '';
    };

    userDirs.createDirectories = lib.mkEnableOption "automatic creation of the XDG user directories";

    userDirs.setSessionVariables = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to set the XDG user dir environment variables, like
        `XDG_DESKTOP_DIR`.

        ::: {.note}
        The recommended way to get these values is via the `xdg-user-dir`
        command or by processing `$XDG_CONFIG_HOME/user-dirs.dirs` directly in
        your application.
        :::
      '';
    };
  };

  config =
    let
      baseDirs = (
        lib.filterAttrs (n: v: !isNull v) {
          XDG_CACHE_HOME = config.baseDirs.cacheHome;
          XDG_CONFIG_HOME = config.baseDirs.configHome;
          XDG_DATA_HOME = config.baseDirs.dataHome;
          XDG_STATE_HOME = config.baseDirs.stateHome;
        }
      );

      userDirs =
        (lib.filterAttrs (n: v: !isNull v) {
          DESKTOP = config.userDirs.desktop;
          DOCUMENTS = config.userDirs.documents;
          DOWNLOAD = config.userDirs.download;
          MUSIC = config.userDirs.music;
          PICTURES = config.userDirs.pictures;
          PUBLICSHARE = config.userDirs.publicShare;
          TEMPLATES = config.userDirs.templates;
          VIDEOS = config.userDirs.videos;
        })
        // config.userDirs.extraConfig;

      # Allow runtime env-var expansion
      esc-fn = wlib.escapeShellArgWithEnv;

      baseDirsSessionVars = lib.mapAttrs (_k: v: {
        data = v;
        inherit esc-fn;
      }) baseDirs;

      userDirsSessionVars = lib.mapAttrs' (k: v: {
        name = "XDG_${k}_DIR";
        value = {
          data = v;
          inherit esc-fn;
        };
      }) userDirs;
    in
    {
      env =
        let
          baseDirsEnabled = config.baseDirs.enable;
          userDirsEnabled = config.userDirs.enable && config.userDirs.setSessionVariables;
        in
        (lib.optionalAttrs baseDirsEnabled baseDirsSessionVars)
        // (lib.optionalAttrs userDirsEnabled userDirsSessionVars);

      extraPackages = lib.mkIf config.userDirs.enable [
        config.userDirs.package
      ];

      runShell =
        let
          mkdir = (dir: ''[[ -L "${dir}" ]] || mkdir -p "${dir}"'');
          createDirs = dirs: (lib.concatMapStringsSep "\n" mkdir (lib.attrValues dirs));

          toKeyValue = pkgs.formats.keyValue { };

          userDirsConf = pkgs.writeText "user-dirs.conf" "enabled=False";
          userDirsDirs =
            let
              # For some reason, these need to be wrapped with quotes to be valid.
              wrapped = lib.mapAttrs' (k: v: {
                name = ''"${k}"'';
                value = v.data;
              }) userDirsSessionVars;
            in
            toKeyValue.generate "user-dirs.dirs" wrapped;

          createBaseDirs = createDirs baseDirs;
          createUserDirs = createDirs userDirs;
          createUserDirsConf = "cp --no-preserve=all ${userDirsConf} \${XDG_CONFIG_HOME}/user-dirs.conf";
          createUserDirsDirs = "cp --no-preserve=all ${userDirsDirs} \${XDG_CONFIG_HOME}/user-dirs.dirs";
        in
        [
          {
            name = "XDG_SETUP";
            data = builtins.concatStringsSep "\n" [
              (lib.optionalString config.baseDirs.enable createBaseDirs)
              (lib.optionalString (config.userDirs.enable && config.userDirs.createDirectories) createUserDirs)
              (lib.optionalString config.userDirs.enable createUserDirsConf)
              (lib.optionalString config.userDirs.enable createUserDirsDirs)
            ];
          }
        ];

      # NOTE: Any shell works here
      package = lib.mkDefault pkgs.bashInteractive;
    };

  meta.maintainers = [ wlib.maintainers.ameer ];
}
