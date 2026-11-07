{
  self,
  lib,
  runCommand,
  writeShellScript,
  stdenv,
  ...
}:
let
  wlib = self.lib;

  _test =
    {
      name,
      debug ? false,
    }:
    testSet:
    let
      testScript = wlib.test.mkTestScript name testSet;
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
wlib.test
// {
  /**
    This function is a wrapped version of `wlib.test.mkTestScript` specific to the `nix-wrapper-modules` repository.

    The tlib variable recieved by the tests in the `nix-wrapper-modules` repository contains all the values in
    [`wlib.test`](https://nix-community.github.io/nix-wrapper-modules/lib/test.html), plus this function.

    Unlike `wlib.test.mkTestScript` this version returns a derivation rather than a string,
    and has more options available for the first argument.

    This function takes tests provided as an attribute set in `testSet`, renders it to a bash script,
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

            ${wlib.test.toSanitizedJSON settings}
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

            ${wlib.test.toSanitizedJSON (lib.attrNames self.wrappers)}
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
}
