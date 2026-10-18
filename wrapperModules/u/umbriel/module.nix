{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  kind =
    let
      s = config.settings;
    in
    if builtins.isAttrs s && !(s ? outPath || s ? __toString) then
      "attrs"
    else if builtins.isString s && !wlib.types.linkable.check s then
      "text"
    else
      "path";

  hasSettings =
    if kind == "attrs" then
      config.settings != { }
    else if kind == "text" then
      config.settings != ""
    else
      true;

  configPath = config.constructFiles.generatedConfig.path;
in
{
  imports = [ wlib.modules.default ];

  config.meta.description = ''
    Wrapper module for [Umbriel](https://docs.noctalia.dev/umbriel/)
  '';

  options = {
    settings = lib.mkOption {
      type = lib.types.oneOf [
        wlib.types.linkable
        lib.types.lines
        (lib.types.attrsOf (
          wlib.types.structuredValueWith {
            typeName = "TOML";
            nullable = false;
          }
        ))
      ];
      default = { };
      example = lib.literalExpression ''
        {
          general.autostart = [ "noctalia" ];
          layout.gap = 5;
          input.keyboard.layout = "us";
          keybinds."Mod+Q" = "window-close";
        }'';
      description = ''
        Umbriel configuration settings.
        May be a Nix attribute set, a TOML string, or a path to a .toml file.

        See <https://docs.noctalia.dev/umbriel/configuration/>

        When empty, no -c flag is added and umbriel reads `$XDG_CONFIG_HOME/umbriel/config.toml`.
      '';
    };
    disableConfigValidation = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `false`, the build runs `umbriel config validate -c <config>` and fails if it reports anything.

        Disabled by default since validation exits non-zero on warnings as well as errors,
        and the home-manager module also drops it.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.umbriel;
    filesToPatch = [
      "share/applications/*.desktop"
      "share/wayland-sessions/*.desktop"
      "lib/systemd/user/umbriel.service"
      "share/systemd/user/umbriel.service"
      "bin/start-umbriel"
    ];
    constructFiles.generatedConfig = lib.mkIf hasSettings {
      relPath = "${config.binName}-config.toml";
      content =
        if kind == "attrs" then
          builtins.toJSON config.settings
        else if kind == "text" then
          config.settings
        else
          "";
      builder =
        if kind == "attrs" then
          ''${pkgs.remarshal}/bin/json2toml "$1" "$2"''
        else if kind == "path" then
          ''cp ${lib.escapeShellArg "${config.settings}"} "$2"''
        else
          ''cp "$1" "$2"'';
    };
    runShell = lib.mkIf hasSettings [
      {
        name = "UMBRIEL_CONFIG_FLAG";
        data = ''
          if [ "$#" -eq 0 ] || [ "$1" = "-s" ]; then
            set -- -c ${lib.escapeShellArg configPath} "$@"
          fi
        '';
      }
    ];
    drv.installPhase = lib.mkIf (hasSettings && !config.disableConfigValidation) ''
      runHook preInstall
      ${lib.getExe config.package} config validate -c ${configPath}
      runHook postInstall
    '';
    passthru.providedSessions = config.package.passthru.providedSessions or [ "umbriel" ];
    meta.maintainers = [ wlib.maintainers.WinterMaximus ];
    meta.platforms = lib.platforms.linux;
  };
}
