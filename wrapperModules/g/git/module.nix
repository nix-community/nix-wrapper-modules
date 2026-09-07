{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];
  options = {
    settings = lib.mkOption {
      inherit (pkgs.formats.gitIni { listsAsDuplicateKeys = true; }) type;
      default = { };
      description = ''
        Git configuration settings.
        See {manpage}`git-config(1)` for available options.
      '';
    };
    configFile = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.gitconfig.path;
      };
      default = { };
      description = "Generated git configuration file.";
    };
  };
  config = {
    env.GIT_CONFIG_GLOBAL = config.configFile.path;
    package = lib.mkDefault pkgs.git;
    constructFiles.gitconfig = {
      relPath = "${config.binName}config";
      content = lib.generators.toGitINI config.settings + "\n" + config.configFile.content;
    };
    meta.maintainers = [ wlib.maintainers.birdee ];
    meta.description = ''
      Nix uses git for all sorts of things. Including fetching flakes!

      So if you put this one in an overlay, name it something other than `pkgs.git`!

      Otherwise you will probably get infinite recursion.

      The vast majority of other packages do not have this issue. And,
      due to the passthrough of `.override` and `.overrideAttrs`,
      most other packages are safe to replace with their wrapped counterpart in overlays directly.
    '';
  };
}
