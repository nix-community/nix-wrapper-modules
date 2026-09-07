{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  toGhosttyConf = lib.generators.toKeyValue {
    listsAsDuplicateKeys = true;
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString = v: if builtins.isBool v then lib.boolToString v else toString v;
    } " = ";
  };
in
{
  imports = [ wlib.modules.default ];

  options.settings = lib.mkOption {
    type =
      let
        atom = lib.types.oneOf [
          lib.types.bool
          lib.types.float
          lib.types.int
          lib.types.str
        ];
      in
      lib.types.attrsOf (lib.types.either (lib.types.listOf atom) atom);
    default = { };
    example = lib.literalExpression ''
      {
        font-size = 14;
        theme = "Catppuccin Mocha";
        window-decoration = false;
        keybind = [
          "ctrl+a>-=new_split:down"
          "ctrl+a>==new_split:right"
        ];
      }
    '';
    description = ''
      Ghostty configuration written to a generated config file. The wrapper
      passes {option}`--config-default-files=false` and
      {option}`--config-file=<generated>`, so the host config is never loaded
      -- including when the wrapper is used ephemerally on a machine that has
      its own Ghostty config. The host config path varies by platform:
      {file}`~/.config/ghostty/config` on Linux, and
      {file}`~/Library/Application Support/com.mitchellh.ghostty/config` on
      macOS.
      See <https://ghostty.org/docs/config/reference> for all available options.

      Note: if you pass an additional {option}`--config-file` flag at runtime,
      Ghostty will merge it on top of the generated config (later files take
      precedence for conflicting keys).

      Note: {command}`ghostty +show-config` and {command}`ghostty
      +validate-config` bypass the generated config entirely (their option
      parsers reject {option}`--config-file`), so they will show the host
      config if one exists -- this affects both installed and ephemeral use.

      On macOS, `ghostty-bin` is used by default, which is the pre-built
      binary distribution [recommended for nix-darwin](https://ghostty.org/docs/install/binary)
      by the Ghostty installation docs.
    '';
  };

  config = {
    filesToPatch = [
      "share/applications/*.desktop"
      "share/dbus-1/services/com.mitchellh.ghostty.service"
      "share/systemd/user/app-com.mitchellh.ghostty.service"
    ];
    package = lib.mkDefault (
      if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty
    );
    constructFiles.ghosttyConfig = {
      content = toGhosttyConf config.settings;
      relPath = "${config.binName}-config";
    };
    addFlag = [
      "--config-default-files=false"
      "--config-file=${config.constructFiles.ghosttyConfig.path}"
    ];
    # Ghostty has no environment variable for specifying a config file, so CLI
    # flags are the only option: --config-default-files=false prevents loading
    # the host's ~/.config/ghostty/config (including on machines where one
    # exists), and --config-file points at the generated one.
    #
    # However, Ghostty +actions and --help have their own minimal Options
    # struct with no _diagnostics field.  Any flag unrecognised by the action
    # parser causes error.InvalidField and a silent exit with no output.
    # argv0type detects these and execs Ghostty directly without injecting any
    # flags.
    #
    # Consequence: +show-config and +validate-config will show the host's
    # ~/.config/ghostty/config if present, not the generated config, because
    # their option parsers also reject --config-file.  This applies equally to
    # installed and ephemeral use.
    argv0type =
      let
        binPath = lib.escapeShellArg config.wrapperPaths.input;
      in
      cmd: ''
        for _ghostty_arg in "$@"; do
          case "$_ghostty_arg" in
            +*|--help) exec -a "$0" ${binPath} "$@";;
          esac
        done
        exec -a "$0" ${cmd}
      '';
    meta.description = "Ghostty terminal emulator";
    meta.maintainers = [ wlib.maintainers.trustworthyadult ];
    meta.platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
