{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:

let
  settingType = lib.types.oneOf [
    lib.types.str
    lib.types.bool
    lib.types.int
    (lib.types.attrsOf settingType)
  ]
  // {
    description = "a GDB setting value, either a str, bool, int, or attribute set";
    descriptionClass = "noun";
    getSubOptions = _: { };
  };

  flattenSetting = (
    value: if lib.isBool value then if value then "on" else "off" else toString value
  );

  flattenSettings =
    prefix: attrs:
    lib.concatLists (
      lib.mapAttrsToList (
        name: value:
        let
          path = if prefix == "" then name else "${prefix} ${name}";
        in
        if lib.isAttrs value then
          flattenSettings path value
        else
          [
            "set ${path} ${flattenSetting value}"
          ]
      ) attrs
    );

  flattenUserCommands =
    attrs:
    lib.mapAttrsToList (name: body: ''
      define ${name}
      ${lib.removeSuffix "\n" body}
      end
    '') attrs;

  makeSettings = settings: lib.concatStringsSep "\n" (flattenSettings "" settings);
  makeUserCommands = userCommands: lib.concatStringsSep "\n" (flattenUserCommands userCommands);

  makeExtensions =
    extensions: lib.concatStringsSep "\n" (map (extension: "source ${extension}") extensions);

  makeGdbinit = phase: ''
    ${makeSettings phase.settings}
    ${makeUserCommands phase.userCommands}
    ${phase.commands}
  '';
in
{
  imports = [ wlib.modules.default ];

  options = {
    earlyInit = {
      settings = lib.mkOption {
        type = lib.types.attrsOf settingType;
        default = { };
        description = ''
          GDB settings to apply during early initialization.

          These settings are processed using GDB's `-eix` option, which executes the generated
          command file early in GDB's startup sequence.

          ```nix
          earlyInit.settings = {
            confirm = false;
            pagination = false;
          };
          ```

          Settings may also be nested to represent GDB's hierarchical `set` commands. For example:
          ```nix
          earlyInit.settings = {
            print = {
              demangle = true;
              symbol = true;
              symbol-filename = true;
            };
          };
          ```
        '';
      };
    };

    init = {
      settings = lib.mkOption {
        type = lib.types.attrsOf settingType;
        default = { };
        description = ''
          GDB settings to apply during normal initialization.

          These settings are written as `set` commands to the generated initialization file and
          are processed using GDB's `-ix` option. The command file is executed after GDB has
          processed its standard initialization files and internal initialization, but before the
          inferior is loaded.

          Boolean values are automatically translated to the corresponding GDB set value: `true`
          becomes `on`, and `false` becomes `off`. For example:
          ```nix
          init.settings = {
            confirm = false;
            pagination = false;
          };
          ```

          Settings may also be nested to represent GDB's hierarchical `set` commands. For example:
          ```nix
          init.settings = {
            print = {
              demangle = true;
              symbol = true;
              symbol-filename = true;
            };
          };
          ```
        '';
      };

      userCommands = lib.mkOption {
        type = lib.types.attrsOf lib.types.lines;
        default = { };
        description = ''
          User-defined GDB commands to define during normal initialization.

          Each attribute name becomes the name of a GDB user-defined command, and its value becomes
          the command body. User-defined commands are written as `define` blocks in the generated
          initialization file and are available after the initialization has completed.
        '';
      };

      commands = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Arbitrary GDB commands to execute during normal initialization.

          The contents are inserted verbatim into the generated initialization file after `settings`
          and `userCommands` have been processed. Commands specified here are therefore executed
          during the `-ix` stage.
        '';
      };
    };

    postInit = {
      settings = lib.mkOption {
        type = lib.types.attrsOf settingType;
        default = { };
        description = ''
          GDB settings to apply after normal initialization.

          These settings are written as `set` commands to a generated command file that is executed
          using GDB's `-x` option. This stage is intended for settings that should be applied after
          the normal GDB initialization performed by the `-ix` stage.

          Boolean values are automatically translated to the corresponding GDB set value: `true`
          becomes `on`, and `false` becomes `off`. For example:
          ```nix
          postInit.settings = {
            confirm = false;
            pagination = false;
          };
          ```

          Settings may also be nested to represent GDB's hierarchical `set` commands. For example:
          ```nix
          postInit.settings = {
            print = {
              demangle = true;
              symbol = true;
              symbol-filename = true;
            };
          };
          ```
        '';
      };

      userCommands = lib.mkOption {
        type = lib.types.attrsOf lib.types.lines;
        default = { };
        description = ''
          User-defined GDB commands to define after normal initialization.

          Each attribute name becomes the name of a GDB user-defined command, and its value becomes
          the command body. The resulting `define` blocks are executed during the post-initialization
          stage.
        '';
      };

      commands = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          GDB commands to execute after normal initialization.

          The contents are inserted verbatim into the generated post-initialization command file after
          `settings` and `userCommands` have been processed. The commands are executed using GDB's `-x`
          option.
        '';
      };
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        GDB extension scripts to source during normal initialization.

        Each path is emitted as a GDB `source` command in the generated initialization file. All
        extensions are therefor loaded as part of the `-ix` stage, after the configured `init.settings`,
        `init.userCommands`, and `init.commands`.

        This option is intended for GDB extensions distributed as scripts, including both GDB scripts
        and Python-based extensions. Any runtime dependencies required by an extension are not added
        automatically and should be provided through `runtimePkgs`.

        The following is an example demonstrating how GDB could be wrapped with GEF:
        ```nix
        inputs.wrapper-modules.wrappers.gdb.wrap {
          inherit pkgs;

          # You could alternatively pull from a URL or provide a local file
          extensions = [
            "''${pkgs.gef}/share/gef/gef.py"
          ];

          # Binary packages required by GEF during runtime
          runtimePkgs = with pkgs; [
            binutils
            file
            procps
          ];

          # Gef can also be configured declartively in during the postInit phase
          postInit = {
            commands = ''''
              gef config context.layout "-legend -regs -code -stack"
              gef config context.clear_screen True
            '''';
          };
        };
        ```
      '';
    };
  };

  config = {
    package = pkgs.gdb;
    runtimePkgs = [ pkgs.python3 ];

    constructFiles = {
      gdbEarlyInit = {
        content = makeSettings config.earlyInit.settings;
        relPath = "share/gdb/gdbEarlyInit";
      };

      gdbInit = {
        content = (makeGdbinit config.init) + (makeExtensions config.extensions);
        relPath = "share/gdb/gdbInit";
      };

      gdbPostInit = {
        content = makeGdbinit config.postInit;
        relPath = "share/gdb/gdbPostInit";
      };
    };

    addFlag = [
      "-eix"
      config.constructFiles.gdbEarlyInit.path
      "-ix"
      config.constructFiles.gdbInit.path
      "-x"
      config.constructFiles.gdbPostInit.path
    ];

    # A long-time GDB enthusiast, yessir yessir :)
    meta.maintainers = [ wlib.maintainers.alexsutila ];
  };
}
