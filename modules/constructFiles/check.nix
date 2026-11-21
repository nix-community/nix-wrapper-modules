{
  pkgs,
  self,
  tlib,
  ...
}:

let
  inherit (tlib)
    areEqual
    fileContains
    notFileContains
    isFile
    test
    ;

  evalWith =
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
    ]).config;

  settings = {
    top = "level";
    section = {
      str = "hello";
      num = 42;
      bool = true;
      list = [
        "a"
        "b"
      ];
    };
  };

  constructsContent =
    {
      structuredAttrs,
      passAsContent,
    }:
    let
      wrapper =
        (evalWith {
          drv.__structuredAttrs = structuredAttrs;
          constructFiles.foo = {
            relPath = "foo.txt";
            content = "raw content";
            inherit passAsContent;
          };
        }).wrapper;
    in
    [
      (isFile "${wrapper}/foo.txt")
      (fileContains "${wrapper}/foo.txt" "^raw content$")
    ];
in
test "constructFiles" {
  "no format keeps the previous behaviour" =
    let
      wrapper =
        (evalWith {
          constructFiles.plain = {
            relPath = "plain.txt";
            content = "raw content";
          };
        }).wrapper;
    in
    [
      (isFile "${wrapper}/plain.txt")
      (fileContains "${wrapper}/plain.txt" "^raw content$")
    ];

  "format = toml generates TOML from value" =
    let
      wrapper =
        (evalWith {
          constructFiles.cfg = {
            relPath = "cfg.toml";
            format = "toml";
            value = settings;
          };
        }).wrapper;
      file = "${wrapper}/cfg.toml";
    in
    [
      (isFile file)
      (fileContains file ''^top = "level"$'')
      (fileContains file ''^\[section\]$'')
      (fileContains file ''^str = "hello"$'')
      (fileContains file "^num = 42$")
      (fileContains file "^bool = true$")
      (fileContains file ''^list = \["a", "b"\]$'')
      (notFileContains file "[{}]")
    ];

  "format = yaml generates YAML from value" =
    let
      wrapper =
        (evalWith {
          constructFiles.cfg = {
            relPath = "cfg.yaml";
            format = "yaml";
            value = settings;
          };
        }).wrapper;
      file = "${wrapper}/cfg.yaml";
    in
    [
      (isFile file)
      (fileContains file "^top: level$")
      (fileContains file "^section:$")
      (fileContains file "^  num: 42$")
      (fileContains file "^  - a$|^    - a$")
    ];

  "format = json writes the JSON as is" =
    let
      cfg = evalWith {
        constructFiles.cfg = {
          relPath = "cfg.json";
          format = "json";
          value = settings;
        };
      };
      file = "${cfg.wrapper}/cfg.json";
    in
    [
      (areEqual (builtins.toJSON settings) cfg.constructFiles.cfg.content)
      (isFile file)
      (fileContains file ''"num":42'')
    ];

  "format works with passAsContent" =
    let
      wrapper =
        (evalWith {
          drv.__structuredAttrs = true;
          constructFiles.cfg = {
            relPath = "cfg.toml";
            format = "toml";
            passAsContent = true;
            value = settings;
          };
        }).wrapper;
      file = "${wrapper}/cfg.toml";
    in
    [
      (isFile file)
      (fileContains file ''^str = "hello"$'')
    ];

  "format works with __structuredAttrs" =
    let
      wrapper =
        (evalWith {
          drv.__structuredAttrs = true;
          constructFiles.cfg = {
            relPath = "cfg.toml";
            format = "toml";
            value = settings;
          };
        }).wrapper;
      file = "${wrapper}/cfg.toml";
    in
    [
      (isFile file)
      (fileContains file ''^str = "hello"$'')
    ];

  "placeholders in value resolve to the final wrapper" =
    let
      wrapper =
        (evalWith (
          { config, ... }:
          {
            constructFiles.cfg = {
              relPath = "nested/dir/cfg.toml";
              format = "toml";
              value.path = "${placeholder config.outputName}/some/file";
            };
          }
        )).wrapper;
      file = "${wrapper}/nested/dir/cfg.toml";
    in
    [
      (isFile file)
      (fileContains file ''^path = "${wrapper}/some/file"$'')
    ];

  "content and builder can still be overridden" =
    let
      wrapper =
        (evalWith {
          constructFiles.cfg = {
            relPath = "cfg.toml";
            format = "toml";
            value = settings;
            builder = ''echo overridden > "$2"'';
          };
        }).wrapper;
    in
    [
      (fileContains "${wrapper}/cfg.toml" "^overridden$")
    ];

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
