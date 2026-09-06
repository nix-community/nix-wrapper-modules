## Overview

This library provides two main components:

It provides the core system via its `lib` output, internally called `wlib`
- `lib.evalModule`: Function to create reusable wrapper modules with type-safe configuration options
  - And related:
    - `lib.evalPackage`: an alias for `evalModule` which returns the package directly
    - `lib.wrapPackage`, which is the same but pre-imports the `wlib.modules.default` module for convenience in creating ad-hoc wrappers
    - A module implementation of `pkgs.makeWrapper` and friends.
    - Several useful nix module system types.
    - etc...

And it serves as a repository for modules for wrapping the programs themselves, allowing knowledge to be shared for you to use!

For that it offers:
- `wlib.wrapperModules`: Pre-made wrapper modules for common packages (`tmux`, `wezterm`, etc.)
- `outputs.wrappers`: a flake output containing partially evaluated forms of the modules in `wrapperModules` for easier access to `.wrap` and other values in the module system directly.

## Usage

Note: there are also template(s) you can access via `nix flake init -t github:nix-community/nix-wrapper-modules`

They will get you started with a module file and the default one also gives you a flake which imports it, for quickly testing it out!

### Using Pre-built Wrapper Modules

```nix
{
  description = ''
    A flake providing a wrapped `wezterm` package with an extra keybind!
  '';
  inputs.wrappers.url = "github:nix-community/nix-wrapper-modules";
  outputs = { self, wrappers }: {
    # These things work without flakes too,
    # but this gives an example from start to finish!
    packages.x86_64-linux.default = wrappers.lib.evalPackage
      ({ config, lib, wlib, pkgs, ... }: {
        pkgs = wrappers.inputs.nixpkgs.legacyPackages.x86_64-linux;
        imports = [ wlib.wrapperModules.wezterm ];
        luaInfo = {
          keys = [
            {
              key = "F12";
              mods = "SUPER|CTRL|ALT|SHIFT";
              action = lib.generators.mkLuaInline "wezterm.action.Nop";
            }
          ];
        };
      });
  };
}
```

```nix
{
  description = ''
    A flake providing a wrapped `mpv` package with some configuration
  '';
  inputs.wrappers.url = "github:nix-community/nix-wrapper-modules";
  inputs.wrappers.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs, wrappers }: let
    forAllSystems = with nixpkgs.lib; genAttrs platforms.all;
  in {
    packages = forAllSystems (system: {
      default = wrappers.wrappers.mpv.wrap (
        {config, wlib, lib, pkgs, ...}: {
          pkgs = import nixpkgs { inherit system; };
          scripts = [ pkgs.mpvScripts.mpris ];
          "mpv.conf".content = ''
            vo=gpu
            hwdec=auto
          '';
          "mpv.input".content = ''
            WHEEL_UP seek 10
            WHEEL_DOWN seek -10
          '';
        }
      );
    });
  };
}
```

### Extending Configurations

The `.eval` function allows you to extend an already-applied configuration with additional modules, similar to `extendModules` in NixOS.

The `.apply` function works the same way, but automatically grabs `.config` from the result of `.eval` for you,
so you can have `.wrap` and `.apply` more easily available without evaluating.

The `.wrap` function works the same way, but automatically grabs `.config.wrapper` (the final package) from the result of `.eval` for you.

The package (via `passthru`) and the modules under `.config` both offer all 3 functions.

```nix
# Apply initial configuration
# you can use `.eval` `.apply` or `.wrap` for this.
initialConfig = (inputs.wrappers.wrappers.tmux.eval ({config, pkgs, ...}{
  # but if you don't plan to provide pkgs yet, you can't use `.wrap` or `.wrapper` yet.
  # config.pkgs = pkgs;
  # but we can still use `pkgs` before that inside!
  config.plugins = [ pkgs.tmuxPlugins.onedark-theme ];
  config.clock24 = false;
})).config;

# Extend with additional configuration!
extendedConfig = initialConfig.apply {
  modeKeys = "vi";
  statusKeys = "vi";
  vimVisualKeys = true;
};

# Access the wrapper!
# apply is useful because we don't need to give it `pkgs` but it gives us
# top level access to `.wrapper`, `.wrap`, `.apply`, and `.eval`
# without having to grab `.config` ourselves
actualPackage = extendedConfig.wrap { inherit pkgs; };
# since we didn't supply `pkgs` yet, we must pass it `pkgs`
# before we are given the new value of `.wrapper` from `.wrap`

# Extend it again! You can call them on the package too!
apackage = (actualPackage.eval {
  prefix = "C-Space";
}).config.wrapper; # <-- `.wrapper` to access the package direcly

# and again! `.wrap` gives us back the package directly
# all 3 forms take modules as an argument
packageAgain = apackage.wrap ({config, pkgs, ...}: {
  # list definitions append when declared across modules by default!
  plugins = [ pkgs.tmuxPlugins.fzf-tmux-url ];
});
```

### Creating Custom Wrapper Modules

```nix
inputs:
(inputs.wrappers.lib.evalModule ({ config, wlib, lib, pkgs, ... }: {
  # You can only grab the final package if you supply pkgs!
  # But if you were making it for someone else, you would want them to do that!

  # config.pkgs = pkgs;

  # include wlib.modules.makeWrapper and wlib.modules.symlinkScript
  imports = [ wlib.modules.default ];
  # The core options are focused on building a wrapper derivation.
  # different wrapper options may be implemented on top, for things like bubblewrap or other tools.
  # `wlib.modules.default` gives you a great module-based pkgs.makeWrapper to use.

  options = {
    profile = lib.mkOption {
      type = lib.types.enum [ "fast" "quality" ];
      default = "fast";
      description = "Encoding profile to use";
    };
    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "./output";
      description = "Directory for output files";
    };
  };

  config.package = pkgs.ffmpeg;
  config.flags = {
    "-preset" = if config.profile == "fast" then "veryfast" else "slow";
  };
  config.env = {
    FFMPEG_OUTPUT_DIR = config.outputDir;
  };
})) # .config.wrapper to grab the final package! Only works if pkgs was supplied.
```

`wrapPackage` comes with `wlib.modules.default` already included, and outputs the package directly!

Use this for quickly creating a one-off wrapped program within your configuration!

```nix
inputs: # <- get the lib somehow
{ pkgs, ... }: {
  home.shellAliases = let
    curlwrapped = inputs.wrappers.lib.wrapPackage ({ config, wlib, lib, ... }: {
      inherit pkgs; # you can only grab the final package if you supply pkgs!
      package = pkgs.curl;
      runtimePkgs = [ pkgs.jq ];
      env = {
        CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };
      flags = {
        "--silent" = true;
        "--connect-timeout" = "30";
      };
      flagSeparator = "=";  # Use --flag=value instead of --flag value (default is " ")
      runShell = [
      ''
        echo "Making request..." >&2
      ''
      ];
    });
  in {
    runCurl = "${lib.getExe curlwrapped}";
  };
}
```

### `nixos`, `home-manager`, And Friends

Because it uses the regular module system and evaluates as a `lib.types.submodule` option,
this library has excellent integration with `nixos`, `home-manager`, `nix-darwin` and any other such systems.

With a single, simple function, you can use any wrapper module directly as a module in `configuration.nix` or `home.nix`!

```nix
# in a nixos module
{ ... }: {
  imports = [
    (inputs.wrappers.lib.getInstallModule { name = "tmux"; value = inputs.wrappers.lib.wrapperModules.tmux; })
  ];
  wrappers.tmux = {
    enable = true;
    modeKeys = "vi";
    statusKeys = "vi";
    vimVisualKeys = true;
  };
}
```

```nix
# in a home-manager module
{ config, lib, ... }: {
  imports = [
    (inputs.wrappers.lib.getInstallModule {
      name = "neovim";
      value = inputs.wrappers.lib.wrapperModules.neovim;
    })
  ];
  wrappers.neovim = { pkgs, lib, ... }: {
    enable = true;
    settings.config_directory = ./nvim;
    specs.stylix = {
      data = pkgs.vimPlugins.mini-base16;
      before = [ "INIT_MAIN" ];
      info = lib.filterAttrs (
        k: v: builtins.match "base0[0-9A-F]" k != null
      ) config.lib.stylix.colors.withHashtag;
      config = /* lua */ ''
        local info, pname, lazy = ...
        require("mini.base16").setup({ palette = info, })
      '';
    };
  };
  home.sessionVariables = let
    # You can still grab the value from config if desired!
    nvimpath = lib.getExe config.wrappers.neovim.wrapper;
  in {
    EDITOR = nvimpath;
    MANPAGER = "${nvimpath} +Man!";
  };
}
```

See the [`wlib.getInstallModule`](../lib/wlib.html#function-library-wlib.getInstallModule) documentation for more info!

### `flake-parts`

This repository also offers a [`flake-parts`](https://github.com/hercules-ci/flake-parts) module!

It offers a template! `nix flake init -t github:nix-community/nix-wrapper-modules#flake-parts`

```nix
{
  description = ''
    Uses flake-parts to set up the flake outputs:

    `wrappers`, `wrapperModules` and `packages.*.*`
  '';
  inputs.wrappers.url = "github:nix-community/nix-wrapper-modules";
  inputs.wrappers.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  outputs =
    {
      self,
      nixpkgs,
      wrappers,
      flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.platforms.all;
      # Import the flake-parts module:
      imports = [ wrappers.flakeModules.wrappers ];

      # provide wrapper modules to flake.wrappers
      flake.wrappers.alacritty = { pkgs, wlib, ... }: {
        imports = [ wlib.wrapperModules.alacritty ];
        settings.terminal.shell.program = "${pkgs.zsh}/bin/zsh";
        settings.terminal.shell.args = [ "-l" ];
      };
      flake.wrappers.xplr = wrappers.lib.wrapperModules.xplr;
      flake.wrappers.tmux =
        { wlib, pkgs, ... }:
        {
          imports = [ wlib.wrapperModules.tmux ];
          plugins = with pkgs.tmuxPlugins; [ onedark-theme ];
        };

      flake.wrappers.tmux-modified = {
        # using flake.wrappers will also make importable forms
        # available in config.flake.wrapperModules!
        imports = [ self.wrapperModules.tmux ];
        # these will add to the above config which added the onedark-theme plugin
        modeKeys = "vi";
        statusKeys = "vi";
        vimVisualKeys = true;
      };

      # no need for getInstallModule with flake-parts!
      flake.nixosModules = builtins.mapAttrs (_: v: v.install) self.wrappers;
      flake.homeModules = self.nixosModules;
      # you don't have to export them from there specifically,
      # this just shows that you can access `.install` directly when using the flake-parts module

      # (optionally) Control which packages get built!
      perSystem =
        { pkgs, ... }:
        {
          # wrappers.pkgs = pkgs; # (optionally) choose a different `pkgs`
          wrappers.control_type = "exclude"; # | "build" (default: "exclude")
          wrappers.packages = {
            tmux-modified = true; # <- set to true to exclude from being built into `packages.*.*` flake output
          };
        };
    };
}
```

The above flake will export the partially evaluated submodules from `outputs.wrappers` as it shows.

However, it also offers the values in importable form from `outputs.wrapperModules` for you!

In addition to that, it will build `packages.*.*` for each of the systems and wrappers for you.

`perSystem.wrappers` options control which packages get built, and with what `pkgs`.

`wrappers.control_type` controls how `wrappers.packages` is handled.

If `wrappers.control_type` is `"exclude"`, then including `true` for a value will exclude its `packages` output.

If you change it to `"build"`, then you must include `true` for all you want to be built.
