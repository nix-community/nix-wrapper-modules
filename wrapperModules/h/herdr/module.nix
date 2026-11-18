{
  config,
  wlib,
  lib,
  pkgs,
  ...
}:

let
  tomlFmtType = wlib.types.structuredValueWith {
    nullable = false;
    typeName = "TOML";
  };
in
{
  imports = [ wlib.modules.default ];

  options.settings = lib.mkOption {
    type = tomlFmtType;
    default = { };
    description = ''
      Herdr configuration options.
      See the Herdr documentation for available options.
    '';
  };

  config = {
    package = lib.mkDefault pkgs.herdr;

    env.HERDR_CONFIG_PATH = config.constructFiles.generatedConfig.path;
    passthru.HERDR_CONFIG_PATH = config.constructFiles.generatedConfig.path;

    constructFiles.generatedConfig = {
      content = builtins.toJSON config.settings;
      relPath = "${config.binName}/config.toml";
      builder = ''
        ${pkgs.remarshal}/bin/json2toml "$1" "$2"
      '';
    };

    meta.maintainers = [ wlib.maintainers.pimkoter ];
  };
}
