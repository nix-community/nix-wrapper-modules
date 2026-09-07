{
  config,
  lib,
  wlib,
  pkgs,
  ...
}@top:
let
  inherit (lib) types;
  rcfile = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.nullOr wlib.types.stringable;
        default = null;
        description = ''
          Path to an rc file to be sourced. If both `.path` and `.content` are specified, `.path` is sourced before `.content`
        '';
      };
      content = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Content of an rc file to be sourced. If both `.path` and `.content` are specified, `.content` is sourced after `.path`
        '';
      };
    };
  };
in
{
  config.meta.description = {
    pre = ''
      Wrapping zsh involves some complexity regarding the global rc files. If zsh is installed
      on the system, /etc/zshenv will be used no matter what. This should not be impactful as
      system maintainers should keep the file from causing unexpected behaviour. The remaining
      global rc files can be skipped using the `skipGlobalRC` option if they are causing conflicts
      with your local rc files.

      For details regarding the rc files see <https://zsh.sourceforge.io/Doc/Release/Files.html#Startup_002fShutdown-Files>.

      This wrapper provides three methods of defining your local rc files.

      You can specify a directory which contains the files.

      You can specify a path to each file directly.

      You can specify the content of each file directly.

      These options can be used together.

      For example:

      If you set `config.zdotdir`, to a directory containing a `.zshrc`, as well as `config.zshrc.path` and `config.zshrc.content`,
      then they would be sourced in the order of `zdotdir`, then `.path`, then `.content`.

      There are a few ways to use this wrapper derivation.

      You could use it inside your terminal config, as the launch command, for example.

      You may also wish to set this as your default shell via a nixos module.

      ```nix
      { config, ... }: {
        imports = [ (wlib.getInstallModule { name = "zsh"; value = ./yourzshwrappermodule.nix; }) ];
        wrappers.zsh.enable = true;
        wrappers.zsh.asSystemDefault = true;
        users.users.''${username}.shell = config.wrappers.zsh.wrapper;
      }
      ```

      - Note:

      `wrapperVariants` in this module have their normal options, however they don't mirror their defaults from top level by default.

      They are instead for wrapping other programs in the context of the zsh wrapper derivation.
    '';
  };
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
    ./zlogin.nix
    ./zlogout.nix
    ./zshenv.nix
    ./zshrc.nix
  ];
  config.package = lib.mkDefault pkgs.zsh;
  # Allow use as a system/user shell
  config.passthru.shellPath = config.wrapperPaths.relPath;
  config.passthru.ZDOTDIR = "${config.wrapper.${config.zdotFilesOutput}}/${config.zdotFilesDirname}";
  config.flags."-d" = config.skipGlobalRC;
  config.meta.maintainers = [
    wlib.maintainers.fluxza
    wlib.maintainers.birdee
  ];
  # I decided not to repeat the same zsh wrapper for all of them
  # rather, if someone wants to use this to wrap other programs in the context of their zsh they can
  # this modifies wrapperVariants slightly with type merging
  options.wrapperVariants = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submoduleWith {
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
  options.generated_zdotdir = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = "${placeholder config.zdotFilesOutput}/${config.zdotFilesDirname}";
    description = ''
      The placeholder for the directory which is created as the ZDOTDIR in the wrapper output

      To get the path from outside of the module, it is declared as ZDOTDIR via passthru as well

      `wrapped-zsh-package.ZDOTDIR` will fetch the path from the output of the wrapper instead.
    '';
  };
  options.zdotFilesDirname = lib.mkOption {
    type = lib.types.str;
    default = "${config.binName}-dot-dir";
    description = "Name of the directory which is created as the zdotdir in the wrapper output";
  };
  options.zdotFilesOutput = lib.mkOption {
    type = lib.types.str;
    default = config.outputName;
    description = "Name of the derivation output where the generated zdotdir is output to.";
  };
  options.skipGlobalRC = lib.mkOption {
    type = types.bool;
    default = false;
    description = ''
      Set the option for zsh to skip loading system level rc files. The system level zshenv
      file cannot be skipped.
    '';
  };
  # no .zprofile because https://zsh.sourceforge.io/Intro/intro_3.html
  options.zdotdir = lib.mkOption {
    type = types.nullOr wlib.types.stringable;
    default = null;
    description = ''
      Direct or string path to a directory containing rc files. The following files will be sourced from
      this directory if they exist: `.zshenv`, `.zshrc`, `.zlogin` and `.zlogout`.
    '';
  };
  options.hmSessionVariables = lib.mkOption {
    type = types.nullOr wlib.types.stringable;
    description = ''
      Absolute path of the `hm-session-vars.sh` script to be loaded.

      For standalone home-manager setups to source `~/.nix-profile/etc/profile.d/hm-session-vars.sh`

      This allows home-manager to provide things such as `home.sessionVariables` to the shell.

      If you import home-manager as a nixos module, you can safely set this to `null`

      You can also obviously safely set it to `null` if you do not use home-manager
    '';
    example = lib.literalMD ''
      ```nix
      "''${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
      ```
    '';
    default = "~/.nix-profile/etc/profile.d/hm-session-vars.sh";
  };
  options.zshenv = lib.mkOption {
    description = ''
      Specifies a file which will be sourced as part of the local `.zshenv` file.

      To be sourced after its corresponding path in `config.zdotdir` if specified.
    '';
    default = { };
    type = rcfile;
  };
  options.zshAliases = lib.mkOption {
    type = types.attrsOf (types.nullOr wlib.types.stringable);
    default = { };
    description = ''
      An attribute set that maps aliases (the top level attribute names in this option) to command
      strings or directly to build outputs. Aliases mapped to null are ignored.

      These aliases are created before any of the rc file options are sourced, therefore,
      aliases specified in those options will override the aliases specified in this option.
    '';
    example = {
      l = null;
      ll = "ls -l";
    };
  };
  options.zshrc = lib.mkOption {
    description = ''
      Specifies a file which will be sourced as part of the local `.zshrc` file.

      To be sourced after its corresponding path in `config.zdotdir` if specified.
    '';
    default = { };
    type = rcfile;
  };
  options.zlogin = lib.mkOption {
    description = ''
      Specifies a file which will be sourced as part of the local `.zlogin` file.

      To be sourced after its corresponding path in `config.zdotdir` if specified.
    '';
    default = { };
    type = rcfile;
  };
  options.zlogout = lib.mkOption {
    description = ''
      Specifies a file which will be sourced as part of the local `.zlogout` file.

      To be sourced after its corresponding path in `config.zdotdir` if specified.
    '';
    default = { };
    type = rcfile;
  };
  config.install.modules.nixos =
    { config, lib, ... }:
    let
      cfg = top.config.install.getWrapperConfig config;
    in
    {
      config = lib.mkMerge [
        (top.config.install.mkWrapperExtension "${./module.nix} zsh as defaultUserShell" {
          _file = ./module.nix;
          options.asSystemDefault = lib.mkEnableOption "zsh as defaultUserShell";
        })
        (lib.mkIf cfg.enable {
          environment.pathsToLink = [ "/share/zsh" ];
          users.defaultUserShell = lib.mkIf cfg.asSystemDefault cfg.wrapper;
          programs.zsh.enable = lib.mkIf cfg.asSystemDefault true;
        })
      ];
    };
}
