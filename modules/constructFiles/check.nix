{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    fileContains
    isFile
    test
    ;

  wrapperWith =
    extraConfig:
    (self.lib.evalModule [
      { inherit pkgs; }
      (
        { wlib, ... }:
        {
          imports = [ wlib.modules.default ];
          package = pkgs.hello;
        }
      )
      extraConfig
    ]).config.wrapper;

  constructsContent =
    {
      structuredAttrs,
      passAsContent,
    }:
    let
      wrapper = wrapperWith {
        drv.__structuredAttrs = structuredAttrs;
        constructFiles.foo = {
          relPath = "foo.txt";
          content = "raw content";
          inherit passAsContent;
        };
      };
    in
    [
      (isFile "${wrapper}/foo.txt")
      (fileContains "${wrapper}/foo.txt" "^raw content$")
    ];
in
test "constructFiles" {
  "passAsContent = false without __structuredAttrs" = constructsContent {
    structuredAttrs = false;
    passAsContent = false;
  };

  "passAsContent = false with __structuredAttrs" = constructsContent {
    structuredAttrs = true;
    passAsContent = false;
  };

  "passAsContent = true without __structuredAttrs" = constructsContent {
    structuredAttrs = false;
    passAsContent = true;
  };

  "passAsContent = true with __structuredAttrs" = constructsContent {
    structuredAttrs = true;
    passAsContent = true;
  };
}
