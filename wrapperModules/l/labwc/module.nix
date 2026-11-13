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
    fonts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        List of font packages to make available to labwc. The wrapper generates a
        fontconfig configuration file from these packages and sets
        `FONTCONFIG_FILE` so that labwc and the applications it launches can find
        the fonts.
      '';
      example = lib.literalExpression ''
        [
          pkgs.cascadia-code
          pkgs.overpass
        ]'';
    };
    cursor = lib.mkOption {
      type = lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path containing one or more cursor theme directories.
              For cursor packages from nixpkgs, this is usually
              `"''${pkgs.somepackage}/share/icons"`.
            '';
            example = lib.literalExpression ''"''${pkgs.oreo-cursors-plus}/share/icons"'';
          };
          theme = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Name of the cursor theme to use. It must match a theme in the
              directory configured by `cursor.path`, or a theme already
              installed on your system (not recommended).
            '';
            example = "oreo_blue_cursors";
          };
          size = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = ''
              Cursor size in pixels.
            '';
            example = 30;
          };
        };
      };
      description = ''
        Cursor settings exported to labwc through the `XCURSOR_PATH`,
        `XCURSOR_THEME`, and `XCURSOR_SIZE` environment variables.
      '';
    };
    configFiles = {
      "rc.xml" = lib.mkOption {
        type = wlib.types.file {
          path = lib.mkOptionDefault config.constructFiles."rc.xml".path;
        };
        default = { };
        description = ''
          The main labwc configuration file. It controls window rules,
          keybindings, themes, and other compositor behavior. Create this file
          with Nix using `content`, or use `path` to point to an existing file.

          For more details, see [all supported configuration elements and attributes](https://github.com/labwc/labwc/blob/master/docs/rc.xml.all) and the [labwc-config man page](https://labwc.github.io/labwc-config.5.html).
        '';
      };
      "menu.xml" = lib.mkOption {
        type = wlib.types.file {
          path = lib.mkOptionDefault config.constructFiles."menu.xml".path;
        };
        default = { };
        description = ''
          The menu definition used by labwc. It describes the root menu and its
          submenus. Create this file with Nix using `content`, or use `path` to
          point to an existing file.

          For more details, see the [labwc-menu man page](https://labwc.github.io/labwc-menu.5.html) and the [reference file](https://github.com/labwc/labwc/blob/master/docs/menu.xml).
        '';
      };
      autostart = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Commands to run when labwc starts. The wrapper writes them to the generated `autostart` script, separating entries with `&`.";
        example = lib.literalExpression ''
          [
            "''${lib.getExe pkgs.swaybg} -c '#334455'"
            "''${lib.getExe pkgs.kitty} --hold ''${lib.getExe pkgs.fastfetch}"
          ]'';
      };
      shutdown = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Commands to run when labwc exits. The wrapper writes them to the generated `shutdown` script, separating entries with `&`.";
      };
    };
  };

  config = {
    package = lib.mkDefault pkgs.labwc;
    meta.description.pre = ''
      Labwc is a [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots)-based stacking compositor for [Wayland](https://wayland.freedesktop.org/), inspired by [Openbox](https://openbox.org/).

      Labwc can be configured using configuration files stored in the `labwc_config/labwc` directory and loaded via `--config-dir`.
      The most common configuration files can be created through the `configFiles` options:

      - `configFiles."rc.xml"` is the main configuration file. It controls window rules, keybindings, themes, and other compositor behavior.
      - `configFiles."menu.xml"` defines the root menu and its submenus.
      - `configFiles.autostart` and `configFiles.shutdown` take lists of commands to run when labwc starts and exits.

      For configuration guides, see these useful resources:

      - [Getting started page](https://labwc.github.io/getting-started.html)
      - [Labwc man pages](https://labwc.github.io/manual.html)
      - Example configuration files for [rc.xml](https://github.com/labwc/labwc/blob/master/docs/rc.xml.all) and [menu.xml](https://github.com/labwc/labwc/blob/master/docs/menu.xml)

      Useful tips:

      - `configFiles."rc.xml"` and `configFiles."menu.xml"` can be created with Nix using the `content` option, or you can point to existing files using the `path` option.
      - To set environment variables instead of using the `environment` configuration file, use the `env` option (`env = { ... }`) provided by the wrapper.
      - Because of the declarative nature of Nix, [labwc-tweaks](https://github.com/labwc/labwc-tweaks) is **not** supported by this wrapper.
      - If you ever need to create additional configuration files beyond those provided by `configFiles`, you can create them yourself using `constructFiles`:

      ```nix
      constructFiles.filename = {
        relPath = "labwc_config/labwc/filename";
        content = '''
          # Content
        ''';
      };
      ```
    '';
    flags."--config-dir" = "${placeholder config.outputName}/labwc_config/labwc";
    env = {
      FONTCONFIG_FILE = pkgs.makeFontsConf {
        fontDirectories = config.fonts;
      };
      XCURSOR_PATH = lib.mkIf (config.cursor.path != null) config.cursor.path;
      XCURSOR_THEME = lib.mkIf (config.cursor.theme != null) config.cursor.theme;
      XCURSOR_SIZE = lib.mkIf (config.cursor.size != null) (toString config.cursor.size);
    };
    constructFiles = {
      "rc.xml" = {
        relPath = "labwc_config/labwc/rc.xml";
        content = config.configFiles."rc.xml".content;
      };
      "menu.xml" = {
        relPath = "labwc_config/labwc/menu.xml";
        content = config.configFiles."menu.xml".content;
      };
      autostart = {
        relPath = "labwc_config/labwc/autostart";
        content = (lib.strings.join " & " config.configFiles.autostart);
      };
      shutdown = {
        relPath = "labwc_config/labwc/shutdown";
        content = (lib.strings.join " & " config.configFiles.shutdown);
      };
    };
    meta.maintainers = [ wlib.maintainers.lodwkobku ];
  };
}
