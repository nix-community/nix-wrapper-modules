{
  pkgs,
  self,
  tlib,
  ...
}:
let
  inherit (tlib)
    isDirectory
    isFile
    test
    ;

  sampleTheme = {
    filekinds.normal.foreground = "Blue";
    perms.user_read = {
      foreground = "Yellow";
      is_bold = true;
    };

    filenames."Cargo.toml".icon.glyph = "🦀";

    nix.icon = {
      glyph = "❄";
      style.foreground = "White";
    };
  };

  ezaWrapper = self.wrappers.eza.wrap {
    inherit pkgs;
    theme = sampleTheme;
  };
in
test { wrapper = "eza"; } {
  "eza wrapper should be created" = isDirectory ezaWrapper;

  "wrapper should output correct version" = ''
    "${ezaWrapper}/bin/eza" --version |
    grep -q "${ezaWrapper.version}"
  '';

  "eza wrapper should contain the theme config file" = isFile "${ezaWrapper}/eza/theme.yml";
}
