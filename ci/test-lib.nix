{
  self,
  lib,
  runCommand,
  writeShellScript,
  stdenv,
  pkgs,
  ...
}:
let
  wlib = self.lib;

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
    if builtins.isAttrs value then
      builtins.toJSON (
        lib.mapAttrsRecursive (
          path: v:
          if builtins.isFunction v then
            let
              res = builtins.unsafeGetAttrPos (lib.last path) (
                lib.getAttrFromPath (lib.sublist 0 (builtins.length path - 1) path) value
              );
            in
            "<lambda${
              if builtins.isAttrs res then
                ":${res.file or ""}:${toString (res.line or "")}:${toString (res.column or "")}"
              else
                ""
            }>"
          else
            v
        ) value
      )
    else
      builtins.toJSON value;

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

  _test =
    {
      name,
      debug ? false,
    }:
    testSet:
    let
      testScript = ''
        run () {
          ${render testSet};
        }
        run || (echo "Test '${name}' failed" >&2 && exit 1)
      '';
    in
    if debug then
      writeShellScript name ''
        ${testScript}
      ''
    else
      runCommand name { passthru.test = testScript; } ''
        ${testScript}
        touch $out
      '';

in
{
  /**
    Takes tests provided as an attrs in `testSet`, renders it to a bash script,
    and executes the rendered script using `pkgs.runCommand`.

    If the command runs successfully, the test set passes. Otherwise, a detailed
    error message describing the failed assertion is shown in the logs.

    # Type
    ```
    test :: (String | AttrSet) -> TestSet -> Derivation
    ```

    where:

    ```
    TestSet :: Test | attrsOf (TestSet | Test)

    Test :: Assertion | [ Assertion ]

    Assertion :: String | { cond :: String; msg :: String; }
    ```

    # Arguments

    settings
    : Either a string or an attrs.

      If it is a string, it will be taken as the name of the derivation built
      by `runCommand`.

      If it is a set, at least one of the keys `name` or `wrapper` need to be set
      with a string value.

      - If you are defining tests for wrappers you should set `settings.wrapper` to the name
      of the wrapper. This way, the `wrapper.meta.platforms` is considered during test execution,
      and the test will only be run if the system it is running on is supported.
      - If `settings.wrapper` is not set, the test will always be run. This makes sense if you
      are testing core options or library functions.
      - If only `settings.wrapper` is set, the name will be derived from this value by suffixing it with `-test`.
      - If `settings.name` is set, it will be taken as the name of the derivation.
      - If both are set, `settings.name` takes precedence.

      There is also an optional boolean option `settings.debug` (default = `false`).
      If it is set to `true`, the generated bash script is built as an executable script that can be inspected
      and run in `result` when running a specific test.

      The test can be disabled by setting `settings.enable = false`.

    testSet
    : The set of tests to run.
  */
  test =
    settings: testSet:
    let
      name =
        if lib.isString settings then
          settings
        else if settings ? name then
          settings.name
        else if settings ? wrapper then
          "${settings.wrapper}-test"
        else
          throw ''
            Invalid argument for `test`.
            The first argument must be either a string (the test name) or an attrs
            with at least one of the keys 'name' or 'wrapper', but got:

            ${lib.toSanitizedJSON settings}
          '';
      wrapperName = settings.wrapper or null;
      platforms =
        if wrapperName == null then
          null
        else if (wrapperName != null) && (lib.hasAttr wrapperName self.wrappers) then
          self.wrappers.${wrapperName}.meta.platforms
        else
          throw ''
            Invalid argument for `test`.
            The provided wrapper '${wrapperName}' was not found.
            Available wrappers are:

            ${lib.toSanitizedJSON (lib.attrNames self.wrappers)}
          '';
      enabled =
        (settings.enable or true)
        && (platforms == null || (platforms != null && builtins.elem stdenv.hostPlatform.system platforms));
    in
    if enabled then
      _test {
        inherit name;
        debug = settings.debug or false;
      } testSet
    else
      null;

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
      msg =
        if !equal then
          ''
            Expected:
              ${toSanitizedJSON expected}
            but got:
              ${toSanitizedJSON actual}''
        else
          "This should never happen.";
    };
}
