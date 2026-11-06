{
  wlib,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          int
          str
          (listOf str)
        ]);
      default = { };
      example = {
        cmd = "yazi-wrapper.sh";
        create_help_file = 0;
        default_dir = "$HOME";
        env = lib.mapAttrsToList (n: v: "${n}=${v}") {
          TERMCMD = "foot";
          EDITOR = "nvim";
        };
        open_mode = "suggested";
        save_mode = "last";
      };
      description = ''
        Configuration of xdg-desktop-portal-termfilechooser.
        See {manpage}`xdg-desktop-portal-termfilechooser(5)`
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.xdg-desktop-portal-termfilechooser;

    binDir = "libexec";
    exePath = "libexec/xdg-desktop-portal-termfilechooser";

    filesToPatch = [
      "share/systemd/user/*.service"
      "share/dbus-1/services/*.service"
    ];

    flags."-c" = config.constructFiles.generatedConfig.path;

    constructFiles.generatedConfig = {
      relPath = "${config.binName}-config";
      content = lib.generators.toINI { listsAsDuplicateKeys = true; } { filechooser = config.settings; };
    };

    meta.maintainers = [ wlib.maintainers.yushisora ];
    meta.platforms = lib.platforms.linux;
  };
}
