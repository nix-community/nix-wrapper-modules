{
  pkgs,
  self,
  tlib,
  ...
}:
let
  inherit (tlib)
    fileContains
    isDirectory
    isFile
    notIsFile
    areEqual
    test
    ;
  default = self.wrappers.stylua.wrap {
    inherit pkgs;
  };
  styluaFile = "styles/stylua.toml";
  styluaToml = "/tmp/stylua.toml";
  styluaTomlContent = ''
    call_parentheses = "None"
    column_width = 100
    quote-style = "ForceSingle"
  '';
in
test { wrapper = "stylua"; } {
  "stylua default wrapper test" = [
    (isDirectory default)
    (notIsFile "${default}/${styluaFile}")
    (notIsFile "${default}/bin/cp_stylua_toml")
    # prepare the test lua file
    ''
      echo "print 'ugly and bad but or and good'" > /tmp/test.lua
    ''
    ''
      output=$("${default}/bin/stylua" -c /tmp/test.lua 2>&1)
      echo "$output" | grep -q 'print("ugly and bad but or and good")'
    ''

    # clean up
    ''
      rm /tmp/test.lua
    ''
  ];

  "customized style wrapper test" =
    let
      styluaWrapper = default.wrap {
        customStyle = {
          call_parentheses = "None";
          column_width = 100;
          quote_style = "ForceSingle";
        };
      };
    in
    [
      (isDirectory styluaWrapper)
      (isFile "${styluaWrapper}/${styluaFile}")
      (fileContains "${styluaWrapper}/${styluaFile}" "${styluaTomlContent}")
      (notIsFile "${styluaWrapper}/bin/cp_stylua_toml")

      # prepare the test lua file
      ''
        echo "print 'ugly and bad but or and good'" > /tmp/test.lua
      ''

      ''
        [[ $(${styluaWrapper}/bin/stylua -c /tmp/test.lua 2>&1) == "" ]]
      ''

      # clean up
      ''
        rm /tmp/test.lua
      ''
    ];

  "copy script enabled wrapper test" =
    let
      cpScriptWrapper = default.wrap {
        customStyle = {
          call_parentheses = "None";
          column_width = 100;
          quote_style = "ForceSingle";
        };
        generateCpScript = {
          enable = true;
        };
      };
    in
    [

      (isDirectory cpScriptWrapper)
      (isFile "${cpScriptWrapper}/${styluaFile}")
      (fileContains "${cpScriptWrapper}/${styluaFile}" "${styluaTomlContent}")
      (isFile "${cpScriptWrapper}/bin/cp_stylua_toml")
      (fileContains "${cpScriptWrapper}/bin/cp_stylua_toml" "bin/sh")

      ''
        cd /tmp && ${cpScriptWrapper}/bin/cp_stylua_toml && cat stylua.toml && rm -f ${styluaToml}
      ''
    ];

  "customized copy script name wrapper test" =
    let
      cpScriptNameWrapper = default.wrap {
        customStyle = {
          call_parentheses = "None";
          column_width = 100;
          quote_style = "ForceSingle";
        };
        generateCpScript = {
          enable = true;
          name = "./bin/test_script";
        };
      };
    in
    [

      (isDirectory cpScriptNameWrapper)
      (isFile "${cpScriptNameWrapper}/${styluaFile}")
      (fileContains "${cpScriptNameWrapper}/${styluaFile}" "${styluaTomlContent}")
      (isFile "${cpScriptNameWrapper}/bin/test_script")
      (fileContains "${cpScriptNameWrapper}/bin/test_script" "bin/sh")

      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script && \
        [[ -e ${styluaToml} ]] && [[ -w ${styluaToml} ]] && \
        grep -i "forcesingle" ${styluaToml} && rm -f ${styluaToml}
      ''

      ''
        ${cpScriptNameWrapper}/bin/test_script -h |
        grep -i "add-doc" && [[ ! -e ${styluaToml} ]]
      ''

      ''
        ${cpScriptNameWrapper}/bin/test_script --help |
        grep -i "add-doc" && [[ ! -e ${styluaToml} ]]
      ''

      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script -i && \
        [[ -e ${styluaToml} ]] && [[ -w ${styluaToml} ]] && \
        grep -i 'enabled = true|false' ${styluaToml} && rm -f ${styluaToml}
      ''

      ''
        cd /tmp && ${cpScriptNameWrapper}/bin/test_script --add-doc && \
        [[ -e ${styluaToml} ]] && [[ -w ${styluaToml} ]] && \
        grep -i 'enabled = true|false' ${styluaToml} && rm -f ${styluaToml}
      ''
    ];

  "copy script only wrapper test" =
    let
      cpScriptOnlyWrapper = default.wrap {
        generateCpScript.enable = true;
      };
    in
    [
      (isDirectory cpScriptOnlyWrapper)
      (isFile "${cpScriptOnlyWrapper}/bin/cp_stylua_toml")
      (notIsFile "${cpScriptOnlyWrapper}/${styluaFile}")

      ''
        cd /tmp && ${cpScriptOnlyWrapper}/bin/cp_stylua_toml | grep "have not generated stylua.toml" \
        && [[ ! -e ${styluaToml} ]]
      ''

      ''
        cd /tmp && ${cpScriptOnlyWrapper}/bin/cp_stylua_toml -i \
        && [[ -e ${styluaToml} ]] && grep 'enabled = true|false' ${styluaToml} && rm -f ${styluaToml}
      ''
    ];
}
