## Adding Modules!

There are 2 kinds of modules in this repository. One kind which defines the `package` option, and one kind which does not.

### Wrapper Modules

If you are making a wrapper module, i.e. one which **does** define the `config.package` option, and thus wraps a package:

You must define a `wrapperModules/<first_letter>/<your_package_name>/module.nix` file.
The file must contain a single, unevaluated module. In other words, it must be importable without calling it like a function first.

All wrapper modules must have a `config.meta.maintainers = [ <your wlib.maintainers listing> ];` entry.

Wrapper modules set `config.package`. They are "for" a program. They import helper module(s) (usually `wlib.modules.default`), and then use those options to provide a module customized for that program.

### Helper Modules

If you are making a helper module, i.e. one which does **not** define the `config.package` option:

You must define a `modules/<your_module_name>/module.nix` file instead.

Just like for wrapper modules, the file must contain a single, unevaluated module. In other words, it must be importable without calling it like a function first.

All helper modules must have a `config.meta.maintainers = lib.mkDefault [ <your wlib.maintainers listing> ];` entry.

Helper modules are meant to either remove boilerplate and improve consistency for common actions, or be a base for making particular kinds of wrapper modules.

It is best practice in a helper module submitted to this repository to avoid relying on other helper modules, e.g. `buildCommand` instead of `constructFiles`, but this is not a hard rule.

For example:

- If someone wanted to provide a common set of options people should implement for themes, they could provide a `wlib.modules.themes` module.
That module could take care of the boilerplate for defining theme options for the module writer, leaving importers of the `wlib.modules.themes` module free to just handle the values in `config`, while also giving people a generally consistent interface.
(If someone were to do that, adding a `wlib.types.palette` type would also be a great first step)

- If someone wanted to provide a `wlib.wrapperModules.nginx-docker`, to make a wrapper module for running `nginx` in a `docker` container.
They might first add a `wlib.modules.docker` that other people could use too, to give the same sort of support we currently offer for `makeWrapper`.
Then they could import the module and implement `nginx-docker` using their new helper module.

### For Both:

All options must have description fields, so that documentation can be generated and people can know how to use it!

You may optionally set the `meta.description` option to provide a short description to include alongside your generated option documentation.

`meta.description` accepts either a set of `{ pre ? "", post ? "" }`, or just a plain string, which will end up as `{ pre = "the string"; post = ""; }`.

`pre` will be added after the title and before the content. `post` will be added after the content.

Do not name an option `options` or `config` if there is a chance the module system will try to use them as if they were top level module declarations.

## Guidelines and Examples:

There are 3 broad categories to use to evaluate a submitted module.

1. Functionality: Does it work? Does it work well? Does it work around the things that don't work well in an acceptable way? (functionality checklist below)

2. Usage and Completeness: Does the user interact with the configuration in a way approximately as nice as the usual workflow? How much of the functionality of the program was able to be wrapped? Do the options adequately cover the needs of the user?

3. Style and Convention: Does it use the right module system types for stuff? Will placeholder paths point to the final generated wrapper derivation in all the options offered by the module? (style tips below)

### Functionality Checklist:

**1. Does the program try to unavoidably modify this file?**

Export functions and GUI configuration wizards that let you specify the configuration directory to modify are fine, as those can be pointed directly into your nix configuration.

Runtime path mechanisms often allow us to create our own directory that we can do whatever we want with.

But if it just modifies the provisioned file, our file is in the store, it is not possible.

This is the main issue that will prevent a wrapper from being made.

We do not have an activation script as we only output derivations.

We do not yet have an organized systemd trigger which is documented as part of user setup in the getting started documentation and included in modules for copying files to impure paths.

So the only current workaround is by injecting shell commands which do the copy when the program launches.

This is obviously less than ideal, and is currently the main blocking issue for accepting a wrapper module for a program into the main repository.

**2. Is it overriding the configuration in the way that has the least impact on the normal command line arguments or functioning of the program?**

If the program offers system and user level configuration, and it merges nicely, should you be overriding the system level path instead?

If the program allows you to specify the path via an environment variable, or a command line argument, are you picking the right one?

To answer that last one, does the command line argument allow later invocations of the flag to override this value or not?

If so, the flag is generally the safest option, otherwise environment variable is the better option in most cases.

**3. Does this program have a runtime caching step after installing a plugin or other configuration change?**

Sometimes it makes sense to do this for users in the wrapper.

Other times it makes sense to leave it up to the user so that they may run it after runtime configuration changes as well.

An unambiguous case where the wrapper should handle it would be if it allows you to do it without impeding the ability for users to run it at runtime as well, for example via a runtime path mechanism.

**4. Is the way in which you are setting the configuration location something that may cause problems for its child processes**

If the program launches many child processes, and to wrap it you need to override something like `$XDG_CONFIG_HOME`, this may not function correctly in many normal use cases.

### Style Tips

When you provide an option to `enable` or `disable` something, you should call it `enable` regardless of its default value.

This prevents people from needing to look it up to use it, and prevents contributors from having to think too hard about which to call it.

- Placeholders, [`config.constructFiles.<name>`](https://nix-community.github.io/nix-wrapper-modules/modules/constructFiles.html), and [`config.buildCommand.<name>`](https://nix-community.github.io/nix-wrapper-modules/lib/core.html#buildcommand)

When you generate a file, it is generally better to do so as a string, and create it using the `constructFiles` option.

This is because, this will make placeholders such as `${placeholder "out"}` work consistently across all your options,
allowing them to all point to the final wrapper derivation rather than several intermediate ones.

What this allows you to do, is manually build files via another option, such as maybe another `constructFiles` entry, and then refer to that created file within your settings!

Making placeholders work in your module makes your modules generally more easily extensible, and is preferred when it is possible to generate a usable string.

It works by using `drv.passAsFile` and making a derivation attribute with the file contents, which is copied into place. It uses a slightly different method when `config.drv.__structuredAttrs == true`, but will still work.

When NOT using `config.constructFiles.<name>` to generate a file, you should use `config.buildCommand.<name>` to do so.

`config.buildCommand.<name>` allows you to include arbitrary build commands to run as part of the wrapper derivation's build process.
By default there is no specific order, but you may specify that this build command run before or after the other build commands it depends on.

- `runShell`, `argv0type`

This only works in the shell backends and does not work in the binary backend. Prefer the other options which do.

- `wlib.types.file`

This type is to be thought of only as a shorthand for a submodule for accepting file content via a nix string that can be overridden via a path instead.

When you provide a `wlib.types.file` option, if it is the main configuration file you should default to something like `configFile`, but if there are multiple you should instead name them something close to their actual filename.

Keep in mind that even if you do not choose to use `wlib.types.file`, the user can usually still override the option that you set to provide the generated path if needed.

So using something like `wlib.types.file` is only truly important when the file you are making an option for is passed to a list-style option, but may still be nice more generally.

Example:

```nix
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
      inherit (pkgs.formats.gitIni { }) type;
      default = { };
      description = ''
        Git configuration settings.
        See {manpage}`git-config(1)` for available options.
      '';
    };
    configFile = lib.mkOption {
      type = wlib.types.file {
        # we can refer to the placeholder of our constructed file!
        path = lib.mkOptionDefault config.constructFiles.gitconfig.path;
        # By default configFile.path points to our generated file.
        # But if users want to provide a path directly, this gives them an easy way to override it.
      };
      default = { };
      description = "Generated git configuration file.";
    };
  };
  config = {
    env.GIT_CONFIG_GLOBAL = config.configFile.path;
    package = lib.mkDefault pkgs.git;
    constructFiles.gitconfig = { # <- constructs the path directly in the final wrapper derivation, such that placeholders work correctly.
      relPath = "${config.binName}config";
      # A string, which is to become the file contents
      content =
        # nixpkgs has a lot of handy generation functions!
        lib.generators.toGitINI config.settings
        # and gitconfig format allows you to arbitrarily append contents!
        + "\n" + config.configFile.content;
    };
    meta.maintainers = [ wlib.maintainers.birdee ]; # <- don't forget to make yourself the maintainer of your module!
  };
}
```

## Formatting

`nix fmt`


## Run Site Generator Locally

`nix run ./ci`

or

`nix run ./ci#docs`

> [!NOTE]
> We also provide a `shell.nix` with a `docs` command that does exactly this.
> Start the devshell (`nix develop`) and type `docs --help` for more info on how to use it.

## Tests


`nix flake check -Lv ./ci`

To run the tests for an individual wrapper only, run

`nix build ./ci#checks.{system}.wrapperModule-{name}`

Example (neovim on `x86_64-linux`):

`nix build ./ci#checks.x86_64-linux.wrapperModule-neovim`

> [!NOTE]
> We also provide a `shell.nix` with a `check` command that does exactly this.
> Start the devshell (`nix develop`) and type `check --help` for more info on how to use it.

## Writing Tests

You may also include a `check.nix` file in your module's directory.

It will be called via `pkgs.callPackage`, provided with the flake `self` value, as well as a test-library `tlib` value.
(i.e. `pkgs.callPackage your_check.nix { inherit self tlib; }`)


We provide a testing library `tlib` that provides an easy-to-use interface to write tests.

### Writing Tests for Wrappers

If you are writing tests for a wrapper module, it is important to pass the name
of the wrapper to the first argument of the `test` function like in the example 
below (marked at `(*)`). By doing this, we can grab the specified `wrapper.meta.platforms`
from the wrapper (if any) and ensure that the tests are only run on the required platforms.


```nix
{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    notFileContains
    isDirectory
    isFile
    notIsFile
    areEqual
    test
    ;
in
test { wrapper = "direnv"; } { # <-- Specify the name of the wrapper here (*)

  "direnv wrapper should be created" =
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
        nix-direnv.enable = true;
      };
    in
    [
      "[[ -d ${wrapper} ]]" # <-- a simple condition to be asserted
      {
        cond = "[[ -d ${wrapper} ]]";
        msg = "No directory found for wrapper."; # <-- you can also specify a custom error message
      }
      (isDirectory wrapper) # <-- or use pre-defined helpers
    ];

  "wrapper should output correct version" =
    let
      wrapper = self.wrappers.direnv.wrap {
        inherit pkgs;
      };
    in
    '' # <-- no need to provide a list if there is only one assertion
      "${wrapper}/bin/direnv" --version |
      grep -q "${wrapper.version}"
    '';

  "math-tests" = { # <-- tests can be arbitrarily grouped
    addition = [
      (areEqual 2 (1 + 1))
      (areEqual 7 (5 + 2))
    ];
    multiplication = [
      (areEqual 1 (1 * 1))
      (areEqual 10 (5 * 2))
    ];
  };
}
```


Pre-defined assertions like `isDirectory` or `areEqual` are already available in `tlib`. 
Feel free to contribute more if you find new ones that other maintainers might benefit from.

### Writing Tests for Helper Modules or Library Functions

The syntax is identical to [the example above](#writing-tests-for-wrappers), 
except you don't provide a wrapper but a name:

```nix
{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    notFileContains
    isDirectory
    isFile
    notIsFile
    areEqual
    test
    ;
in
test "my-test" { # <-- Specify an arbitrary name for your test
# test { name = "my-test" } { # <-- This is equivalent

  "my first test" = [ ... ]; # <-- nothing new here
  "my second test" = [ ... ];
}
```

If you are writing a helper module, or something very complex, you may wish to have multiple derivations. Simply return a set of them instead.

## Commit Messages

Changes to wrapper modules should be titled `<type>(wrapperModules.<name>): some description`.
For new additions, the description should be `init`, with any further explanation on subsequent lines

Changes to helper modules should be titled `<type>(modules.<name>): some description`.
For new additions, the description should be `init`, with any further explanation on subsequent lines

For `lib` additions and changes, the description should be `<type>(lib.<set>.<name>): some description` or `<type>(lib.<name>): some description`.

For template additions and changes, the description should be `<type>(templates.<name>): some description`.

Changes to the core options set defined in `lib/core.nix` should be titled `<type>(core.<option>): some description`.

`<type>` refers to a one word tag [like `feat`, `fix`, `docs`, or `test`](https://gist.github.com/Zekfad/f51cb06ac76e2457f11c80ed705c95a3#commit-types) as specified by [Conventional Commits](https://www.conventionalcommits.org)

For everything else, do the best you can to follow conventional commit message style.

Why specify this? I was having trouble figuring out what to title my commits. So now I know.

## Questions?

The [github discussions board](https://github.com/nix-community/nix-wrapper-modules/discussions) is open and a great place to find help!
