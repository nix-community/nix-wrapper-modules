{
  pkgs,
  lib,
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
          constructFiles.foo = {
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
          constructFiles.foo = {
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
        constructFiles.foo = {
          relPath = "cfg.json";
          format = "json";
          value = settings;
        };
      };
      file = "${cfg.wrapper}/cfg.json";
    in
    [
      (areEqual (builtins.toJSON settings) cfg.constructFiles.foo.content)
      (isFile file)
      (fileContains file ''"num":42'')
    ];

  "format with __structuredAttrs and passAsContent (stdin builder)" =
    let
      wrapper =
        (evalWith {
          drv.__structuredAttrs = true;
          constructFiles.foo = {
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

  "format with __structuredAttrs (temp file builder)" =
    let
      wrapper =
        (evalWith {
          drv.__structuredAttrs = true;
          constructFiles.foo = {
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
            constructFiles.foo = {
              relPath = "nested/dir/cfg.toml";
              format = "toml";
              value.some_file = "${placeholder config.outputName}/some/file";
            };
          }
        )).wrapper;
      file = "${wrapper}/nested/dir/cfg.toml";
    in
    [
      (isFile file)
      (fileContains file ''^some_file = "${wrapper}/some/file"$'')
    ];

  "content and builder can still be overridden" =
    let
      wrapper =
        (evalWith {
          constructFiles.foo = {
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

  "value merges attrsets recursively and concatenates lists" =
    let
      cfg = evalWith {
        imports = [
          {
            constructFiles.foo = {
              relPath = "cfg.json";
              format = "json";
              value = {
                ui.sound.enabled = false;
                list = [ "a" ];
              };
            };
          }
          {
            constructFiles.foo.value = {
              ui.theme = "dark";
              list = [ "b" ];
            };
          }
        ];
      };
    in
    [
      (areEqual {
        ui = {
          sound.enabled = false;
          theme = "dark";
        };
        list = [
          "a"
          "b"
        ];
      } (builtins.fromJSON cfg.constructFiles.foo.content))
    ];

  "value rejects non-serializable values" =
    let
      cfg = evalWith {
        constructFiles.foo = {
          relPath = "cfg.json";
          format = "json";
          value.nested.fn = x: x;
        };
      };
    in
    [
      (areEqual false (builtins.tryEval cfg.constructFiles.foo.content).success)
    ];

  "value type follows format" =
    let
      valueType =
        format:
        (evalWith {
          constructFiles.foo = {
            relPath = "cfg";
            inherit format;
          };
        }).constructFiles.foo;
      evalNull =
        format:
        (evalWith {
          constructFiles.foo = {
            relPath = "cfg";
            inherit format;
            value.key = null;
          };
        }).constructFiles.foo.content;
    in
    [
      # null is rejected at evaluation time for TOML only
      (areEqual false (builtins.tryEval (evalNull "toml")).success)
      (areEqual true (builtins.tryEval (evalNull "json")).success)
      (areEqual true (builtins.tryEval (evalNull "yaml")).success)
      # format = null keeps working (value is unused)
      (areEqual "" (valueType null).content)
    ];

  "format and value must be set together" =
    let
      evaluates =
        def:
        (builtins.tryEval
          (evalWith {
            constructFiles.foo = {
              relPath = "foo";
            }
            // def;
          }).constructFiles.foo.content
        ).success;
    in
    [
      # both set or neither set: ok
      (areEqual true (evaluates {
        format = "toml";
        value.key = "x";
      }))
      (areEqual true (evaluates { }))
      (areEqual false (evaluates {
        format = "toml";
      }))
      (areEqual false (evaluates {
        value.key = "x";
      }))
      # even a mkDefault definition counts as "set"
      (areEqual false (evaluates {
        value = lib.mkDefault { key = "x"; };
      }))
    ];

  "shorthand value types" =
    let
      inherit (self.lib.types) tomlValue jsonValue yamlValue;
    in
    [
      (areEqual "TOML value" tomlValue.description)
      (areEqual "JSON value" jsonValue.description)
      (areEqual "YAML value" yamlValue.description)
      (areEqual false (tomlValue.check null))
      (areEqual true (jsonValue.check null))
      (areEqual true (yamlValue.check null))
      (areEqual true (tomlValue.check { a.b = [ 1 ]; }))
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
