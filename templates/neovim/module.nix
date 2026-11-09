inputs:
{
  config,
  wlib,
  lib,
  pkgs,
  options,
  ...
}:
{
  imports = [ wlib.wrapperModules.neovim ];
  # NOTE: see the tips and tricks section or the bottom of this file + flake inputs to understand this value
  options.nvim-lib.neovimPlugins = lib.mkOption {
    readOnly = true;
    type = lib.types.attrsOf wlib.types.stringable;
    # Makes plugins autobuilt from our inputs available with
    # `config.nvim-lib.neovimPlugins.<name_without_prefix>`
    default = config.nvim-lib.pluginsFromPrefix "plugins-" inputs;
  };

  # choose a directory for your config.
  config.settings.config_directory = ./.;
  # you can also use an impure path!
  # config.settings.config_directory = lib.generators.mkLuaInline "vim.fn.stdpath('config')";
  # config.settings.config_directory = "/home/<USER>/.config/nvim";
  # If you do that, it will not be provisioned by nix, but it will have normal reload for quick edits!

  # If you want to install multiple neovim derivations via home.packages or environment.systemPackages
  # in order to prevent path collisions:

  # set this to true:
  # config.settings.dont_link = true;

  # and make sure these dont share values:
  # config.binName = "nvim";
  # config.settings.aliases = [ ];

  # To add a wrapped $out/bin/${config.binName}-neovide to the resulting neovim derivation
  # config.hosts.neovide.nvim-host.enable = true;

  # You can declare your own options!
  options.settings.colorscheme = lib.mkOption {
    type = lib.types.str;
    default = "onedark_dark";
  };
  config.settings.colorscheme = "moonfly"; # <- just demonstrating that it is an option
  # and grab it in lua with `require(vim.g.nix_info_plugin_name)("onedark_dark", "settings", "colorscheme") == "moonfly"`
  config.specs.colorscheme = {
    lazy = true;
    data = builtins.getAttr config.settings.colorscheme (
      with pkgs.vimPlugins;
      {
        "onedark_dark" = onedarkpro-nvim;
        "onedark_vivid" = onedarkpro-nvim;
        "onedark" = onedarkpro-nvim;
        "onelight" = onedarkpro-nvim;
        "moonfly" = vim-moonfly-colors;
      }
    );
  };
  # If you don't want the boilerplate of a whole option in settings, you could just pass stuff
  config.info.testvalue = {
    some = "stuff";
    goes = "here";
  };
  # and grab it in lua with `require(vim.g.nix_info_plugin_name)(nil, "info", "testvalue", "some") == "stuff"`
  # Tip: in your nvim command line run:
  # `:lua require('lzextras').debug.display(require(vim.g.nix_info_plugin_name))`
  config.settings.anothertestvalue = {
    settings = "can also accept freeform values";
  };

  # If the defaults are fine, you can just provide the `.data` field
  # In this case, a list of specs, instead of a single plugin like above
  config.specs.lze = [
    # if defaults is fine, you can just provide the `.data` field
    config.nvim-lib.neovimPlugins.lze
    # but these can be specs too!
    {
      # these ones can't take lists though
      data = config.nvim-lib.neovimPlugins.lzextras;
      # things can target any spec that has a name.
      name = "lzextras";
      # now something else can be after = [ "lzextras" ]
      # the spec name is not the plugin name.
      # to override the plugin name, use `pname`
      # You could run something before your main init.lua like this
      # before = [ "INIT_MAIN" ];
      # You can include configuration and translated nix values here as well!
      # type = "lua"; # | "fnl" | "vim"
      # info = { };
      # config = ''
      #   local info, pname, lazy = ...
      # '';
    }
  ];

  # you can name these whatever you want.
  config.specs.nix = {
    data = null;
    runtimePkgs = with pkgs; [
      nixd
      nixfmt
    ];
  };
  # You can use the before and after fields to run them before or after other specs or spec of lists of specs
  config.specs.lua = {
    after = [ "general" ];
    lazy = true;
    data = with pkgs.vimPlugins; [
      lazydev-nvim
    ];
    runtimePkgs = with pkgs; [
      lua-language-server
      stylua
    ];
  };

  config.specs.general = {
    # this would ensure any config included from nix in here will be ran after any provided by the `lze` spec
    # If we provided any from within either spec, anyway
    after = [ "lze" ];
    # note we didn't have to specify the `lze` specs name, because it was a top level spec
    runtimePkgs = with pkgs; [
      lazygit
      tree-sitter
    ];
    # this `lazy = true` definition will transfer to specs in the contained DAL, if there is one.
    # This is because the definition of lazy in `config.specMods` checks `parentSpec.lazy or false`
    # the submodule type for `config.specMods` gets `parentSpec` as a `specialArg`.
    # you can define options like this too!
    lazy = true;
    # here we chose a DAL of plugins, but we can also pass a single plugin, or null
    # plugins are of type wlib.types.stringable
    data = with pkgs.vimPlugins; [
      {
        data = vim-sleuth;
        # You can override defaults from the parent spec here
        lazy = false;
      }
      snacks-nvim
      nvim-lspconfig
      nvim-surround
      vim-startuptime
      blink-cmp
      blink-compat
      cmp-cmdline
      colorful-menu-nvim
      lualine-nvim
      gitsigns-nvim
      which-key-nvim
      fidget-nvim
      nvim-lint
      conform-nvim
      nvim-treesitter-textobjects
      # treesitter + grammars
      nvim-treesitter.withAllGrammars
      # This is for if you only want some of the grammars
      # (nvim-treesitter.withPlugins (
      #   plugins: with plugins; [
      #     nix
      #     lua
      #   ]
      # ))
    ];
  };

  # These are from the tips and tricks section of the neovim wrapper docs!
  # https://nix-community.github.io/nix-wrapper-modules/neovim.html#tips-and-tricks
  # We could put these in another module and import them here instead!

  # This submodule modifies both levels of your specs
  config.specMods =
    {
      # When this module is ran in an inner list,
      # this will contain `config` of the parent spec
      parentSpec ? null,
      # and this will contain `options`
      # otherwise they will be `null`
      parentOpts ? null,
      parentName ? null,
      # and then config from this one, as normal
      config,
      # and the other module arguments.
      ...
    }:
    {
      # you could use this to change defaults for the specs
      # config.collateGrammars = lib.mkDefault (parentSpec.collateGrammars or false);
      # config.autoconfig = lib.mkDefault (parentSpec.autoconfig or false);
      # config.runtimeDeps = lib.mkDefault (parentSpec.runtimeDeps or false);
      # config.pluginDeps = lib.mkDefault (parentSpec.pluginDeps or false);
      # or something more interesting like:
      # add a runtimePkgs field to the specs themselves
      options.runtimePkgs = options.runtimePkgs // {
        description = ''
          A runtimePkgs spec field to put packages on the PATH
          If the spec is disabled, this value will not be included in the resulting neovim derivation
        '';
      };
      # You could do this too
      # config.before = lib.mkDefault [ "INIT_MAIN" ];
    };
  config.runtimePkgs = config.specCollect (acc: v: acc ++ (v.runtimePkgs or [ ])) [ ];

  # Inform our lua of which top level specs are enabled
  options.settings.cats = lib.mkOption {
    readOnly = true;
    type = lib.types.attrsOf lib.types.bool;
    default = builtins.mapAttrs (_: v: v.enable) config.specs;
  };
  # build plugins from inputs set
  options.nvim-lib.pluginsFromPrefix = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    default =
      prefix: inputs:
      lib.pipe inputs [
        builtins.attrNames
        (builtins.filter (s: lib.hasPrefix prefix s))
        (map (
          input:
          let
            name = lib.removePrefix prefix input;
          in
          {
            inherit name;
            value = config.nvim-lib.mkPlugin name inputs.${input};
          }
        ))
        builtins.listToAttrs
      ];
  };
}
