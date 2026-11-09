{
  lib,
  wlib,
  pkgs,
  config,
  ...
}:
let
  yamlFmtType = wlib.types.structuredValueWith {
    typeName = "YAML";
  };
in
{
  imports = [ wlib.modules.default ];

  options = {
    theme = lib.mkOption {
      type = yamlFmtType;
      default = { };
      description = ''
        Theme configuration for eza.
        See <https://github.com/eza-community/eza/blob/main/man/eza_colors-explanation.5.md> for all available options.
      '';
    };
  };

  config = {
    package = lib.mkDefault pkgs.eza;

    env.EZA_CONFIG_DIR = lib.dirOf config.constructFiles.generatedTheme.path;

    constructFiles.generatedTheme = {
      content = builtins.toJSON config.theme;
      relPath = "${config.binName}/theme.yml"; # You must name the file `theme.yml`, no matter the directory you specify
      builder = ''${pkgs.remarshal}/bin/json2yaml "$1" "$2"'';
    };

    meta.maintainers = [ wlib.maintainers.ionawr ];
  };
}
