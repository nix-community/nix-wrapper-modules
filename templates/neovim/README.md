# Neovim module

This is a demonstration of the [neovim module](https://nix-community.github.io/nix-wrapper-modules/wrapperModules/neovim.html)

It makes use of the tips in the [tips and tricks](https://nix-community.github.io/nix-wrapper-modules/wrapperModules/neovim.html#tips-and-tricks) section of the documentation.

This template configuration is by no means a perfect, complete configuration.

However, it is plenty to start on, and covers some interesting ways to use the module (and how to lazily load plugins and config).

This configuration is 1 `lua` file, however the whole set of directories from a normal `neovim` configuration directory are available.

To see what directories you can put stuff in, see: [:help 'rtp'](https://neovim.io/doc/user/options.html#'rtp')

The main reason it is in 1 file is that it is following the style of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim).

The other reason it is in 1 file, is that it makes it a cleaner experience to init this template into an existing configuration.

This template config uses [lze](https://github.com/BirdeeHub/lze) for lazy loading of the configuration.

You may also be interested in [lz.n](https://github.com/lumen-oss/lz.n) for this purpose.

Both achieve the same general result and main interface,
but have different underlying implementations and thus have different handler features.

Both are fantastic for lazy loading with both nix and the builtin plugin manager.

You may also decide you don't need lazy loading at all. This is fine, many plugins mostly handle that themselves.

To initialize this template flake into the current directory, run:

```bash
nix flake init -t github:nix-community/nix-wrapper-modules#neovim
```

It will not replace existing files.

If you are using `zsh` you may need to escape the `#`

To build it from that directory

```bash
nix build .
```

It exports a package! (and other things)

If you don't want your config in a separate flake, just call the `module.nix` file like:

```nix
inputs: # <-- get the library somehow
{ pkgs, ... }: {
  # call the module and install the package (nixos example)
  environment.systemPackages = [ (inputs.nix-wrapper-modules.lib.evalPackage [ ./module.nix { inherit pkgs; } ]) ];
}
```

There are a lot of other ways to install it as well, see [the getting started documentation](https://nix-community.github.io/nix-wrapper-modules/md/getting-started.html)

You may also wish to view the `flake.nix` of this template, as it demonstrates some of those things when setting up its outputs.

---

The nix in this template is not as simple as it could possibly be, as it demonstrates some things
from the [tips and tricks](https://nix-community.github.io/nix-wrapper-modules/wrapperModules/neovim.html#tips-and-tricks) section of the documentation.

If you wanted as simple as possible, you could use something more like the following as your `module.nix`

```nix
{ wlib, config, pkgs, lib, ... }:
  imports = [ wlib.wrapperModules.neovim ];
  specs.general = with pkgs.vimPlugins; [
    # plugins which are loaded at startup ...
  ];
  specs.lazy = {
    lazy = true;
    data = with pkgs.vimPlugins; [
      # plugins which are not loaded until you vim.cmd.packadd them ...
    ];
  };
  runtimePkgs = with pkgs; [
    # lsps, formatters, etc...
  ];
  settings.config_directory = ./.; # or lib.generators.mkLuaInline "vim.fn.stdpath('config')";
}
```

At the same time, you may find that the `module.nix` file from this template is not massively more complex than that either,
and contains some useful tricks and information.
