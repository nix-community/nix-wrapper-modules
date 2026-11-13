{
  wlib,
  pkgs,
  config,
  lib,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };

  configJson = config.settings // {
    plugins = map (p: "${p}/plugin.wasm") config.plugins;
  };
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      inherit (jsonFormat) type;
      default = { };
      description = ''
        Settings to add to dprint.json.
      '';
      example = {
        excludes = [
          "**/node_modules"
          "**/*-lock.json"
        ];
        json = { };
        malva = { };
        markdown = { };
        toml = { };
        typescript = { };
        yaml = { };
      };
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Plugins to add to dprint runtime.
      '';
      example = lib.literalExpression ''
        plugins = with pkgs.dprint-plugins; [
          g-plane-pretty_yaml
          dprint-plugin-typescript
          dprint-plugin-json
          dprint-plugin-markdown
          dprint-plugin-toml
          g-plane-malva
        ];
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.dprint;

    constructFiles.generatedConfig = {
      relPath = "${config.binName}-config.json";
      content = builtins.toJSON configJson;
    };

    flags = {
      "--config" = config.constructFiles.generatedConfig.path;
    };

    meta.maintainers = [ wlib.maintainers.rachitvrma ];
  };
}
