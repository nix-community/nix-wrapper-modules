{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };
in
{
  imports = [ wlib.modules.default ];
  options = {
    generatedConfigDirname = lib.mkOption {
      type = lib.types.str;
      default = "${config.binName}";
      description = "Name of the directory which is created as the NOCTALIA_CONFIG_HOME in the wrapper output";
      apply = x: lib.removePrefix "/" (lib.removeSuffix "/" x);
    };
    configDrvOutput = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = "Name of the derivation output where the generated NOCTALIA_CONFIG_HOME is output to.";
    };
    configPlaceholder = lib.mkOption {
      type = lib.types.str;
      default = "${placeholder config.configDrvOutput}/${config.generatedConfigDirname}";
      readOnly = true;
      description = ''
        The placeholder for the generated config directory.

        Use this inside the module to place files in an ad-hoc manner within it.

        Outside of the module, you should instead use `wrapped-noctalia.generatedConfig` to get the path.
      '';
    };
    settings = lib.mkOption {
      type = wlib.types.structuredValueWith { typeName = "TOML"; };
      default = { };
      description = ''
        Noctalia configuration settings as an attribute set,
        to be written to $NOCTALIA_CONFIG_HOME/noctalia/settings.toml`.
      '';
    };
    colors = lib.mkOption {
      type = wlib.types.structuredValueWith { typeName = "JSON"; };
      default = { };
      description = ''
        Noctalia color configuration as an attribute set, written to $NOCTALIA_CONFIG_HOME/noctalia/custom.json.
        Set `theme.custom_palette = "custom"` in settings to use the custom color scheme.
      '';
    };
  };

  config = {
    env = {
      NOCTALIA_CONFIG_HOME = "${placeholder config.configDrvOutput}";
    };
    passthru.generatedConfig = "${
      config.wrapper.${config.configDrvOutput}
    }/${config.generatedConfigDirname}";
    constructFiles.settings = {
      content = builtins.readFile (
        tomlFmt.generate config.constructFiles.settings.relPath config.settings
      );
      output = lib.mkOverride 0 config.configDrvOutput;
      relPath = lib.mkOverride 0 "noctalia/settings.toml";
    };
    constructFiles.colors = {
      content = builtins.toJSON config.colors;
      output = lib.mkOverride 0 config.configDrvOutput;
      relPath = lib.mkOverride 0 "noctalia/palettes/custom.json";
    };
    package = lib.mkDefault pkgs.noctalia;
    meta.maintainers = [ wlib.maintainers.jasdeep ];
    meta.description = ''
      `noctalia` provides a gui interface for settings which stores overriden settings in $XDG_STATE_HOME 
    '';
  };
}
