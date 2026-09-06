# [nix-wrapper-modules](https://birdeehub.github.io/nix-wrapper-modules/)

A Nix library to create wrapped executables via the module system.

Are you annoyed by rewriting modules for every platform? nixos, home-manager, nix-darwin, devenv?

Then this library is for you!

## What is this for?

When configuring programs using nix, one of the highlights for most is the module system.

The main "configuration.nix" file of NixOS and "home.nix" for home-manager contain all sorts of shortlist options. For a while, it's great!

But then you need to use your configuration somewhere else. Pulling in your home-manager configuration on some other machine is usually overkill, takes too long, and is often a destructive action, as it will link files into the home directory and move the old files.

You don't want to pull in your entire home environment, you just needed to do some pair programming and wanted to use some of your tools, not destroy your co-workers dotfiles. Can't you make like, a shell, or a derivation or something and use that directly?

In addition, you often have some modules that might be duplicated because NixOS or home-manager options can be different. And you can't use any of that in a shell. It is starting to wear on you a bit.

So you hear about this thing called "wrapping" a package. This means, writing a script that launches the program with specific arguments or variables set, and installing that instead.

Then, you could have your configured tools as derivations you can just install via any means nix has of installing something.

Nix makes this concept very powerful, as you can create files and pull in other programs without installing them globally.

Your first attempt, you might write something that looks like this:

```nix
pkgs.writeShellScriptBin "alacritty" (let
  tomlcfg = pkgs.writeText "alacritty.toml" ''
    [terminal.shell]
    program = "${pkgs.zsh}/bin/zsh"
    args = [ "-l" ]
  '';
in ''
  exec ${pkgs.alacritty}/bin/alacritty --config-file ${tomlcfg} "$@"
'')
```

This is good! Kinda. If you install it, it will install the wrapper script instead of the program, and the script tells it where the config is! And it doesn't need home-manager or NixOS!

But on closer inspection, its missing a lot. What if this were a package with a few more things you could launch? Where is the desktop file? Man pages?

So, your next attempt might look more like this:

```nix
pkgs.symlinkJoin (let
  tomlcfg = pkgs.writeText "alacritty.toml" ''
    [terminal.shell]
    program = "${pkgs.zsh}/bin/zsh"
    args = [ "-l" ]
  '';
in {
  name = "alacritty";
  paths = [ pkgs.alacritty ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/alacritty --add-flag --config-file --add-flag ${tomlcfg}
  '';
})
```

Ok. So maybe that isn't your second try. But you get there eventually.

This is a little closer to how stuff like nixvim works, if you have heard of it. It just has a lot more on top of that.

But even this has problems. If you want to have any sensible ability to override this later, for example, you will need to add that ability yourself.

You also now have a desktop file that might point to the wrong place. And if all you wanted to do was set a setting or 2 and move on, all of that will still be necessary to deal with.

You eventually are reduced to going to the source code of a bunch of modules in nixpkgs or home-manager and copy pasting what they did into your wrapper.

What if I told you, you can solve all those problems, and gain a really nice, consistent, and flexible way to do this, and make sure it can always be overridden later?

And it uses something you already know! The module system!

```nix
inputs.nix-wrapper-modules.wrappers.alacritty.wrap {
  inherit pkgs;
  settings.terminal.shell.program = "${pkgs.zsh}/bin/zsh";
  settings.terminal.shell.args = [ "-l" ];
}
```

The above snippet does everything the prior 2 examples did, and then some!

That's a full module (defined like [this](https://github.com/BirdeeHub/nix-wrapper-modules/blob/main/wrapperModules/a/alacritty/module.nix) and with docs [here](https://birdeehub.github.io/nix-wrapper-modules/wrapperModules/alacritty.html)) but just for that package, and the result is a fully portable derivation, just like the wrapper scripts above!

And you can call `.wrap` on it as many times as you want! You can define your own options
to easily toggle things for your different use cases and re-export it in a flake and change them on import, etc.

And you do not lose your ability to use `.override` or `.overrideAttrs` on the original package!

The arguments will be passed through to the value of `config.package`,
and the result will persist within the module system for future evaluations!

As a result it is safe to replace the vast majority of packages with their wrapped counterpart in an overlay directly.

There are included modules for several programs already, but there are rich and easy to use options defined for creating your own modules as well!

If you make one, you are encouraged to submit it here for others to use if you wish!

For more information on how to do this, check out the [getting started](https://birdeehub.github.io/nix-wrapper-modules/md/getting-started.html) documentation, and the descriptions of the module options you have at your disposal!

## What programs can I configure in this way?

Not every program cooperates well with being wrapped, but a large portion of them do.

The criteria for a program to be a cooperative candidate for a wrapper derivation are as follows:

- The program should give you a way to tell it where all the pieces of its configuration are. Preferably _only_ its own configuration and not all of `XDG_CONFIG_HOME`.
  - Ideally this includes plugins, which should have a runtime path mechanism of some kind to allow side by side installation from both nix AND at runtime.
- It should not unavoidably write to those files or directories specified in that manner at runtime.

If the program fulfills those 2 conditions, you will be able to wrap that program with no unsolved issues!

It is generally good practice for programs to follow these rules.
Runtime-generated information is supposed to live in `XDG_CACHE_HOME`, `XDG_DATA_HOME`, and `XDG_STATE_HOME` rather than in user configuration.
Writing to configuration files at runtime makes versioning those files difficult, and users generally expect to be able to move their configuration to a location of their choosing for easier provisioning and organization.

Unfortunately there are also many programs which do not follow these rules.
You might be able to wrap them still, but you will run into more issues.

Hopefully future helper modules utilizing technologies like `bubblewrap` can help with programs that give no way to specify configuration location.

Criteria number 2 is because the file/directory is in the nix store and thus not writable.
This is circumventable only by copying files out of the nix store at runtime, and is often an issue for NixOS and Home-Manager as well.

## Roadmap

Desired core library additions:

- Per-module documentation generation options or functions usable by the end user for their own modules in their configuration.
- A `bubblewrap` helper module which can help wrap difficult packages. Maybe also a `sandbox-exec` version for mac users.
- Mac-only fixes for issues such as re-wrapping things in a binary wrapper for derivation locations that on macos require binaries.
- DBus and udev service file options similar to the ones for systemd.

We also accept prebuilt wrapper modules for common programs!

This allows people to quickly jump in with using this project for those programs without needing to research the program's configuration mechanisms thoroughly enough to make a wrapper themselves.

Contributors are what makes projects like these which contain modules for so many programs amazing! Thank you for your hard work!

## Related Extension Projects:

There may be projects that offer useful additions or pre-configurations of existing modules,
or new ways of using wrapper modules that do not yet fit in the main repository.

For example, a collection of Neovim modules for various languages would be a good item for this list

- [hm-wrapper-modules](https://github.com/sini/hm-wrapper-modules)
  - This is a library designed to run home manager modules, figure out what paths it would add,
    and use `bubblewrap` and a wrapper module to use the home manager module as a wrapper module.
  - This repository may be useful to create wrapper modules for difficult to wrap programs until more direct ones can be written.
  - It does not fit in the main repository, because the correct way to do it is to add a `bubblewrap` helper module to the main repository,
    and figure out what files that program actually needs us to wrap via `bubblewrap` or not.

Hopefully more will be listed here soon!

Some examples why something may not fit in the main repository:

- It doesn't fit in an existing category of offered things.

- It requires more flake inputs beyond `nixpkgs` in order to import it from this repository and use it somewhere.

- It is a never ending job of its own (i.e. making modules for new editor language integrations and plugins for an existing wrapper module like the Neovim one)

---

### Why rewrite [lassulus/wrappers](https://github.com/Lassulus/wrappers)?

Yes, I know about this comic [(xkcd 927)](https://xkcd.com/927/), but it was necessary that I not heed the warning it gives. 

For those paying attention to the recent nix news, you may have heard of a similar project which was released recently.

This excellent video by Vimjoyer was made, which mentions the project this one is inspired by at the end.

[![Homeless Dotfiles with Nix Wrappers](https://img.youtube.com/vi/Zzvn9uYjQJY/0.jpg)](https://www.youtube.com/watch?v=Zzvn9uYjQJY)

The video got that repository a good amount of attention. And the idea of the `.apply` interface was quite good, although I did implement it in my own way.

Most of the video is still applicable though! It is short and most of its runtime is devoted to explaining the problem being solved.
So, if you still find yourself confused as to what problem this repository is solving, please watch it!

But the mentioned project gives you very little control from within the module system
over what is being built as your wrapper derivation. (the thing you are actually trying to create)

It was designed around a module system which can supply some of the arguments of some separate builder function designed to be called separately,
which itself does not give full control over the derivation.

This repository was designed around giving you absolute control over the _derivation_ your wrapper is creating from **within** the module system, and defining modules for making the experience making wrapper modules great.

In short, this repo is more what it claims to be. A generalized and effective module system for creating wrapper derivations, and offers far more abilities to that effect to the module system itself.

This allows you to easily modify your module with extra files and scripts or whatever else you may need!

Maybe you want your `tmux` wrapper to also output a launcher script that rejoins a session, or creates one? You can do that using this project with, for example, a `drv.postBuild` hook! Just like in a derivation, and you can even use `"${placeholder "out"}"` in it!

But you can supply it [from within the module system](https://birdeehub.github.io/nix-wrapper-modules/lib/core.html#drv)! You could then define an option to customize its behavior later!

In addition, the way it is implemented allows for the creation of helper modules that wrap derivations in all sorts of ways, which you could import instead of `wlib.modules.default` if you wanted. We could have similar modules for wrapping projects via bubblewrap or into docker containers with the same ease with which this library orchestrates regular wrapper scripts.

It makes a lot of improvements, both to the basic wrapping options, and to the module system as a whole.

Things like:

- A `wlib.types.subWrapperModuleWith` type which works like `lib.types.submoduleWith` (and can be used in other things which use the nixpkgs module system)
- Fine-grained control over the actual wrapper derivation you are making with options like `config.drv` and `config.passthru` (and others...)
- You can call `.extendModules` from the evaluated result without problems.
- A customizable type which normalizes "specs" for you, `wlib.types.specWith`/`wlib.types.spec`.
- `wlib.types.dagOf` (set form) and `wlib.types.dalOf` (list form) use the `spec` type to normalize a list or set of values or specs to a form sortable by `wlib.dag.topoSort`
- And for the wrapper script generation options:
  - The full suite of options you are used to from `pkgs.makeWrapper`, but in module form, and with full control of the order even across options.
  - Choose between multiple backend implementations with a single line of code without changing any other options:
    - `nix` which is the default, like `shell` but allows runtime variable expansion rather than build time
    - `shell` which uses `pkgs.makeWrapper`
    - `binary` which uses `pkgs.makeBinaryWrapper`
  - `${placeholder "out"}` works correctly in this module, pointing to the final wrapper derivation
  - Ordering of flags on a fine-grained basis (via the DAG and DAL types mentioned above)
  - Customizing of flag separator per item (via those same types)
  - Customizing of escaping function per item (same thing here...)
  - and more...
- and more...

While both projects have surface level similarities, this repository is in fact a full rewrite, with a quite significant increase in functionality!
