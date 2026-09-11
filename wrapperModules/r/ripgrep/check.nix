{
  pkgs,
  self,
  lib,
  tlib,
  ...
}:
let
  inherit (lib) getExe const genList;
  inherit (tlib) test;
in
test { wrapper = "ripgrep"; } {
  "ripgrep binary and version check" =
    let
      wrapper = self.wrappers.ripgrep.wrap {
        inherit pkgs;
        settings.xyz = true;
      };
    in
    [
      {
        cond = ''[[ -x "${wrapper}/bin/rg" ]]'';
        msg = "ripgrep binary (rg) is missing or not executable";
      }
      {
        cond = "${getExe wrapper} --version | grep -q ${wrapper.version}";
        msg = "ripgrep version does not match wrapper version";
      }
    ];

  "ripgrep settings check" =
    let
      wrapper = self.wrappers.ripgrep.wrap {
        inherit pkgs;
        settings = {
          hidden = true;
          u = genList (const true) 3;
        };
      };
    in
    [
      {
        cond = ''
          mkdir -p $out
          echo hidden > $out/.hidden
          ${getExe wrapper} -q hidden $out
        '';
        msg = "'settings.hidden' config was not passed to ripgrep";
      }
      {
        cond = "${getExe wrapper} -q hello ${getExe pkgs.hello}";
        msg = "'settings.u' (-uuu) flag was not passed to ripgrep";
      }
    ];

  "ripgrep ignore check" =
    let
      wrapper = self.wrappers.ripgrep.wrap {
        inherit pkgs;
        ignores = ''
          *-ignore-*
        '';
      };
    in
    {
      cond = ''
        mkdir -p $out
        echo ignored > $out/please-ignore-me
        ! ${getExe wrapper} -q hidden $out
      '';
      msg = "Ignores glob were not applied to ripgrep";
    };
}
