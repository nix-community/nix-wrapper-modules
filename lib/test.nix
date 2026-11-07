{ wlib, lib }:
let
  errMsg = msg: "(echo \"${renderMsg msg}\" >&2 && return 1)";

  indentBlock =
    str: num:
    let
      idnt = "  ";
      lines = lib.splitString "\n" str;
      indentLine = line: (wlib.repeatStr idnt num) + line;
    in
    lib.concatMapStringsSep "\n" indentLine lines;

  # Use [ANSI-C Quoting](https://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html#ANSI_002dC-Quoting-1)
  # to properly display multi-line messages without being indented if occurring in deeply nested tests.
  renderMsg =
    str:
    let
      lines = lib.splitString "\n" str;
      result = "$'${lib.concatStringsSep "\\n" lines}'";
    in
    if (lib.length lines) == 1 then str else result;

  toSanitizedJSON =
    value:
    let
      sanitize =
        in_list: parentAttrs: name: v:
        # intentionally ignores and recurses into functors
        if builtins.isFunction v then
          let
            res =
              if parentAttrs == null || name == null then null else builtins.unsafeGetAttrPos name parentAttrs;
            args = builtins.functionArgs v;
          in
          "<lambda${
            lib.optionalString (builtins.isAttrs res) "${
              if in_list then " in list at " else ":"
            }${res.file or ""}:${toString (res.line or "")}:${toString (res.column or "")}"
            +
              lib.optionalString (args != { })
                "; with arguments ${
                  lib.pipe args [
                    (lib.mapAttrsToList (n: v: "`${n}${lib.optionalString v "?"}`"))
                    (builtins.concatStringsSep ", ")
                  ]
                }"
          }>"
        else if builtins.isList v then
          map (sanitize true parentAttrs name) v
        # lets builtins.toJSON handle derivations
        else if builtins.isAttrs v && !lib.isStringLike v then
          lib.mapAttrs (sanitize false v) v
        else
          v;
    in
    builtins.toJSON (sanitize false null null value);

  render =
    node:
    let
      renderAssertion =
        let
          _renderAssertion =
            { cond, msg }:
            ''
              (
                ${cond}
              ) || ${errMsg msg}'';
        in
        assertion:
        if lib.isString assertion then
          _renderAssertion {
            cond = assertion;
            msg = "Failed assertion: ${assertion}";
          }
        else
          _renderAssertion assertion;

      renderAssertions =
        assertions: lib.concatMapStringsSep " &&\n" (a: "(${renderAssertion a})") assertions;

      isAssertion =
        x:
        lib.isString x
        || (
          lib.isAttrs x
          &&
            lib.attrNames x == [
              "cond"
              "msg"
            ]
        );

      renderNode =
        node:
        let
          block =
            if lib.isList node || isAssertion node then
              renderAssertions (lib.toList node)
            else
              lib.concatMapAttrsStringSep " &&\n" (name: childNode: ''
                ((
                ${renderNode childNode}
                ) || ${errMsg name})'') node;
        in
        indentBlock block 1;
    in
    renderNode node;

  mkTestScript = name: testSet: ''
    run () {
      ${render testSet};
    }
    run || (echo "Test '${name}' failed" >&2 && exit 1)
  '';
in
{
  /**
    Takes tests provided as an attribute set in `testSet`, renders it to a bash script returned as a string.

    If the script runs successfully, the test set passes.

    Otherwise, it exits with the error code 1 and a detailed
    error message describing the failed assertion is printed.

    # Type
    ```
    mkTestScript :: String -> TestSet -> String
    ```

    where:

    ```
    TestSet :: Test | attrsOf (TestSet | Test)

    Test :: Assertion | [ Assertion ]

    Assertion :: String | { cond :: String; msg :: String; }
    ```

    # Arguments

    name
    : Printed if the test fails as part of the message

    testSet
    : The set of tests to run.

    # Example

    ```nix
      { pkgs, wlib }: let
      name = "math-tests";
      inherit (wlib.test) areEqual;
      testSet = {
        addition = [
          (areEqual 2 (1 + 1))
          (areEqual 7 (5 + 2))
        ];
        multiplication = [
          (areEqual 1 (1 * 1))
          (areEqual 10 (5 * 2))
        ];
      };
      in pkgs.runCommand name {} ''
        ${wlib.test.mkTestScript name testSet}
        touch $out
      '';
    ```
  */
  mkTestScript = mkTestScript;

  /**
    Returns an `Assertion` that checks whether `path` is an existing directory.

    # Type
    ```
    isDirectory :: String -> Assertion
    ```

    # Arguments
    path
    : The filesystem path to check.
  */
  isDirectory = path: {
    cond = ''[[ -d "${path}" ]]'';
    msg = "No such directory ${path}";
  };

  /**
    Returns an `Assertion` that checks whether `path` is an existing regular file.

    # Type
    ```
    isFile :: String -> Assertion
    ```

    # Arguments
    path
    : The filesystem path to check.
  */
  isFile = path: {
    cond = ''[ -f "${path}" ]'';
    msg = "No such file ${path}";
  };

  /**
    Returns an `Assertion` that checks whether `path` does **not** exist as a regular file.

    # Type
    ```
    notIsFile :: String -> Assertion
    ```

    # Arguments
    path
    : The filesystem path that should be absent.
  */
  notIsFile = path: {
    cond = ''[ ! -f "${path}" ]'';
    msg = "File ${path} should not exist";
  };

  /**
    Returns an `Assertion` that checks whether `path` does **not** exist as a directory.

    # Type
    ```
    notIsFile :: String -> Assertion
    ```

    # Arguments
    path
    : The filesystem path that should be absent.
  */
  notIsDirectory = path: {
    cond = ''[ ! -d "${path}" ]'';
    msg = "Directory ${path} should not exist";
  };

  /**
    Returns an `Assertion` that checks whether `file` contains a line matching `pattern`.

    The check is performed with `grep -Eq`, so `pattern` is treated as an extended regular expression.

    # Type
    ```
    fileContains :: String -> String -> Assertion
    ```

    # Arguments
    file
    : Path to the file to search.

    pattern
    : Extended regular expression to search for.
  */
  fileContains = file: pattern: {
    cond = ''grep -Eq -- '${pattern}' "${file}"'';
    msg = "Pattern '${pattern}' not found in ${file}";
  };

  /**
    Returns an `Assertion` that checks whether `file` does not contain a line matching `pattern`.

    The check is performed with `! grep -Eq`, so `pattern` is treated as an extended regular expression.

    # Type
    ```
    notFileContains :: String -> String -> Assertion
    ```

    # Arguments
    file
    : Path to the file to search.

    pattern
    : Extended regular expression to search for.
  */
  notFileContains = file: pattern: {
    cond = ''! grep -Eq -- '${pattern}' "${file}"'';
    msg = "Pattern '${pattern}' found in ${file}";
  };

  /**
    Returns an `Assertion` that checks whether `expected` and `actual` are equal.

    The comparison is performed in Nix at evaluation time. If the values differ,
    the assertion message shows both values serialised as JSON.

    # Type
    ```
    areEqual :: Any -> Any -> Assertion
    ```

    # Arguments
    expected
    : The expected value.

    actual
    : The value to compare against `expected`.
  */
  areEqual =
    expected: actual:
    let
      equal = expected == actual;
    in
    {
      cond = if equal then "true" else "false";
      msg = ''
        Expected:
          ${toSanitizedJSON expected}
        but got:
          ${toSanitizedJSON actual}
      '';
    };

  /**
    Recieves any nix value and prints a json representation of it.

    Calls `builtins.toJSON`, but replaces all functions with a description first.

    Useful for printing values as part of messages for failed tests.

    Will recurse into functors, but not derivations.
  */
  toSanitizedJSON = toSanitizedJSON;
}
