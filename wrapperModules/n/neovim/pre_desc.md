Please see the template for an introductory example usage!

To initialize it, run [`nix flake init -t github:nix-community/nix-wrapper-modules#neovim`](https://github.com/nix-community/nix-wrapper-modules/tree/main/templates/neovim)

If you are using `zsh`, you may need to escape the `#` character with a backslash.

The first thing to notice is `config.settings.config_directory`

Set it to an in-store, out-of-store, or `lib.generators.mkLuaInline` value!

It will be loaded just like a normal `neovim` configuration directory.

Plugins are provided via the `config.specs` option.

It takes a set of plugins, or a set of lists of plugins.

Each item that accepts a plugin may also be a `spec` with the plugin as its `.data` field,
which may optionally be customized by `config.specMods` and then further processed by `config.specCollect` (not too hard) and `config.specMaps` (advanced).

The spec forms offer the ability to provide plugins, configuration (in `lua`, `vimscript`, or `fennel`),
along with automatically translated lua values from nix in a finely controlled order.

A plugin may be an in-store or out-of-store path, but may not be an inline lua value.

Optionally supports the ability to avoid path collisions when installing multiple configured `neovim` packages!

You may do this via a combination of `config.binName` and `config.settings.dont_link` options.

This module provides an info plugin you can access in lua to get metadata about your nix install, as well as ad-hoc values you pass.

This module fully supports remote plugin hosts.

By the same mechanism, it also allows arbitrary other items to be bundled into the context of your `neovim` derivation, such as `neovide`,
via an option which accepts wrapper modules for maximum flexibility.

A basic usage of this module might look something like this:

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
  info = {
    values = "for lua";
    which = "will be placed in the generated info plugin for access";
  };
  runtimePkgs = with pkgs; [
    # lsps, formatters, etc...
  ];
  settings.config_directory = ./.; # or lib.generators.mkLuaInline "vim.fn.stdpath('config')";
}
```

Please also check out the [Tips and Tricks](#tips-and-tricks) section for more information!
