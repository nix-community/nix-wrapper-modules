{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib) test;
in
test { wrapper = "gdb"; } {
  "wrapper initialization" =
    let
      wrapper = self.wrappers.gdb.wrap {
        inherit pkgs;
      };
    in
    "[[ -x ${wrapper}/bin/gdb ]]";

  "early initialization settings" =
    let
      wrapper = self.wrappers.gdb.wrap {
        inherit pkgs;

        earlyInit.settings = {
          confirm = false;
          pagination = false;

          print = {
            demangle = true;
            symbol = true;
          };
        };
      };
    in
    ''
      gdbinit="${wrapper}/share/gdb/gdbEarlyInit"
      [[ -f "$gdbinit" ]]

      grep -Fxq "set confirm off" "$gdbinit"
      grep -Fxq "set pagination off" "$gdbinit"
      grep -Fxq "set print demangle on" "$gdbinit"
      grep -Fxq "set print symbol on" "$gdbinit"
    '';

  "initialization settings and commands" =
    let
      wrapper = self.wrappers.gdb.wrap {
        inherit pkgs;

        init = {
          settings = {
            confirm = false;
            pagination = false;
          };

          userCommands.foo = ''
            echo hello
          '';

          commands = ''
            echo initialized
          '';
        };
      };
    in
    ''
      gdbinit="${wrapper}/share/gdb/gdbInit"
      [[ -f "$gdbinit" ]]

      grep -Fxq "set confirm off" "$gdbinit"
      grep -Fxq "set pagination off" "$gdbinit"
      grep -Fxq "define foo" "$gdbinit"
      grep -Fxq "echo hello" "$gdbinit"
      grep -Fxq "end" "$gdbinit"
      grep -Fxq "echo initialized" "$gdbinit"
    '';

  "post initialization" =
    let
      wrapper = self.wrappers.gdb.wrap {
        inherit pkgs;

        postInit = {
          settings = {
            confirm = false;
            pagination = false;
          };

          userCommands.foo = ''
            echo hello
          '';

          commands = ''
            echo post-initialized
          '';
        };
      };
    in
    ''
      gdbinit="${wrapper}/share/gdb/gdbPostInit"
      [[ -f "$gdbinit" ]]

      grep -Fxq "set confirm off" "$gdbinit"
      grep -Fxq "set pagination off" "$gdbinit"
      grep -Fxq "define foo" "$gdbinit"
      grep -Fxq "echo hello" "$gdbinit"
      grep -Fxq "end" "$gdbinit"
      grep -Fxq "echo post-initialized" "$gdbinit"
    '';

  "extensions" =
    let
      extension = pkgs.writeText "test-extension.gdb" ''
        echo extension-loaded
      '';

      wrapper = self.wrappers.gdb.wrap {
        inherit pkgs;
        extensions = [ extension ];
      };
    in
    ''
      gdbinit="${wrapper}/share/gdb/gdbInit"
      [[ -f "$gdbinit" ]]

      grep -Fxq "source ${extension}" "$gdbinit"
    '';
}
