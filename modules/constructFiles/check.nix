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

  # NOTE: passAsContent only works together with __structuredAttrs
  # (also true for the default builder on main).
  "format with __structuredAttrs and passAsContent (stdin builder)" =
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

  "format with __structuredAttrs (temp file builder)" =
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

  "value merges attrsets recursively and concatenates lists" =
    let
      cfg = evalWith {
        imports = [
          {
            constructFiles.cfg = {
              relPath = "cfg.json";
              format = "json";
              value = {
                ui.sound.enabled = false;
                list = [ "a" ];
              };
            };
          }
          {
            constructFiles.cfg.value = {
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
      } (builtins.fromJSON cfg.constructFiles.cfg.content))
    ];

  "value rejects non-serializable values" =
    let
      cfg = evalWith {
        constructFiles.cfg = {
          relPath = "cfg.json";
          format = "json";
          value.nested.fn = x: x;
        };
      };
    in
    [
      (areEqual false (builtins.tryEval cfg.constructFiles.cfg.content).success)
    ];

  "value type follows format" =
    let
      valueType =
        format:
        (evalWith {
          constructFiles.cfg = {
            relPath = "cfg";
            inherit format;
          };
        }).constructFiles.cfg;
      evalNull =
        format:
        (evalWith {
          constructFiles.cfg = {
            relPath = "cfg";
            inherit format;
            value.key = null;
          };
        }).constructFiles.cfg.content;
    in
    [
      # null is rejected at evaluation time for TOML only
      (areEqual false (builtins.tryEval (evalNull "toml")).success)
      (areEqual true (builtins.tryEval (evalNull "json")).success)
      (areEqual true (builtins.tryEval (evalNull "yaml")).success)
      # format = null keeps working (value is unused)
      (areEqual "" (valueType null).content)
    ];

  "setting value without format is an error" =
    let
      contentWith =
        valueDef:
        (evalWith {
          constructFiles.cfg = {
            relPath = "cfg";
            value = valueDef;
          };
        }).constructFiles.cfg.content;
    in
    [
      (areEqual false
        (builtins.tryEval (contentWith {
          key = "x";
        })).success
      )
      # even a mkDefault definition counts as "set"
      (areEqual false (builtins.tryEval (contentWith (lib.mkDefault { key = "x"; }))).success)
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
}
