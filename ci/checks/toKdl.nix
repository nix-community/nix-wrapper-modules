{
  pkgs,
  self,
  ...
}:
let
  lib = pkgs.lib;
  toKdl = self.lib.toKdl;

  assertions = [
    {
      description = "plain node";
      expected = ''"a" '';
      actual = toKdl { a = _: { }; };
    }
    {
      description = "primitive as argument";
      expected = ''"b" 1'';
      actual = toKdl { b = 1; };
    }
    {
      description = "list of primitives as multiple args";
      expected = ''"c" "x" 2 #true #null'';
      actual = toKdl {
        c = [
          "x"
          2
          true
          null
        ];
      };
    }
    {
      description = "attrset as child block";
      expected = "\"d\"  {\n  \"x\" 1\n}";
      actual = toKdl {
        d = {
          x = 1;
        };
      };
    }
    {
      description = "list of attrsets as repeated child nodes";
      expected = "\"e\"  {\n  \"x\" 1\n  \"x\" 2\n}";
      actual = toKdl {
        e = [
          { x = 1; }
          { x = 2; }
        ];
      };
    }
    {
      description = "function with props only";
      expected = ''"h" "k"="v"'';
      actual = toKdl {
        h = _: {
          props = {
            k = "v";
          };
        };
      };
    }
    {
      description = "function with props custom content";
      expected = ''"h" "k"=r#"v"#'';
      actual = toKdl {
        h = _: {
          props = {
            k = _: { custom = ''r#"v"#''; };
          };
        };
      };
    }
    {
      description = "function with content only";
      expected = "\"i\"  {\n  \"j\" 1\n}";
      actual = toKdl {
        i = x: {
          content = {
            j = 1;
          };
        };
      };
    }
    {
      description = "function with props and content";
      expected = "\"f\" \"arg1\" \"key1\"=\"val\" \"key2\"=r#\"val\"# {\n  \"g\" \n}";
      actual = toKdl {
        f = _: {
          props = [
            "arg1"
            { key1 = "val"; }
            { key2 = _: { custom = ''r#"val"#''; }; }
          ];
          content = {
            g = _: { };
          };
        };
      };
    }
    {
      description = "nested structure";
      expected = "\"k\"  {\n  \"l\"  {\n    \"m\" \"a\"\n    \"m\" \"b\"\n  }\n}";
      actual = toKdl {
        k = {
          l = [
            { m = "a"; }
            { m = "b"; }
          ];
        };
      };
    }
    {
      description = "top-level list of attrsets";
      expected = "\"a\" 1\n\"b\" 2";
      actual = toKdl [
        { a = 1; }
        { b = 2; }
      ];
    }
    {
      description = "null value";
      expected = ''"n" #null'';
      actual = toKdl { n = null; };
    }
    {
      description = "mixed args and block";
      expected = "\"mixed\" \"arg1\" {\n  \"child\" \"val\"\n}";
      actual = toKdl {
        mixed = _: {
          props = "arg1";
          content = {
            child = "val";
          };
        };
      };
    }
  ];

  failedAssertions = builtins.filter (a: a.expected != a.actual) assertions;
  numPassed = builtins.length (builtins.filter (a: a.expected == a.actual) assertions);
  numFailed = builtins.length failedAssertions;
  reportFailed = lib.concatMapStringsSep "\n" (a: ''
        - ${a.description}:
          Expected (${toString (builtins.stringLength a.expected)} chars):
    ${lib.concatMapStringsSep "\n" (l: "        ${l}") (lib.splitString "\n" a.expected)}
          Actual (${toString (builtins.stringLength a.actual)} chars):
    ${lib.concatMapStringsSep "\n" (l: "        ${l}") (lib.splitString "\n" a.actual)}
  '') failedAssertions;
in
pkgs.runCommand "toKdl-test" { } ''
  echo "Testing toKdl function..."
  echo ""
  if [ ${toString numFailed} -gt 0 ]; then
    echo "FAILED: ${toString numFailed} test(s) failed, ${toString numPassed} passed"
    echo ""
    echo "Failed tests:"
    echo "${reportFailed}"
    exit 1
  else
    echo "PASSED: All ${toString numPassed} tests passed!"
    touch $out
  fi
''
