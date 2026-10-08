{
  pkgs,
  self,
  tlib,
  ...
}:
let
  inherit (tlib)
    isDirectory
    isFile
    test
    ;
in
test { wrapper = "quickshell"; } {
  "wrapper should output correct version" =
    let
      wrapper = self.wrappers.quickshell.wrap {
        inherit pkgs;
      };
    in
    ''
      "${wrapper}/bin/quickshell" --version |
      grep -q "${wrapper.version}"
    '';

  "wrapper should create config dir" =
    let
      wrapper = self.wrappers.quickshell.wrap {
        inherit pkgs;
      };
    in
    isDirectory "${wrapper}/${wrapper.passthru.configuration.binName}-config";

  "file tests" =
    let
      baseWrapper = self.wrappers.quickshell.apply {
        inherit pkgs;

        env.LANG = "C.utf8";
        env.LC_ALL = "C.utf8";
        env.XDG_RUNTIME_DIR = "/tmp";
      };

      shellContent = ''
        Scope {
          Bar {}
        }
      '';
      barContent = ''
        import Quickshell // for PanelWindow
        import QtQuick // for Text

        PanelWindow {
          anchors {
            top: true
            left: true
            right: true
          }

          implicitHeight: 30

          Text {
            anchors.centerIn: parent
            text: "hello world"
          }
        }
      '';

      isShellPresent =
        wrapper: isFile "${wrapper}/${wrapper.passthru.configuration.binName}-config/shell.qml";
      isBarPresent =
        wrapper: mod:
        isFile "${wrapper}/${wrapper.passthru.configuration.binName}-config/${
          if mod != null then "${mod}/" else ""
        }Bar.qml";
      isCorrectConfig = wrapper: ''
        logs=$("${wrapper}/bin/quickshell" 2>&1)
        echo "$logs" | grep -q "Launching config: \"${wrapper}/${wrapper.passthru.configuration.binName}-config/shell.qml\""
      '';
    in
    {
      "wrapper should load shell.qml and components" =
        let
          wrapper = baseWrapper.wrap {
            configFile = shellContent;
            components.bar = barContent;
          };
        in
        [
          (isShellPresent wrapper)
          (isBarPresent wrapper null)
          (isCorrectConfig wrapper)
        ];

      "wrapper should load external files" =
        let
          wrapper = baseWrapper.wrap {
            configFile = pkgs.writeText "quickshell-test-shell.qml" shellContent;
            components.bar = pkgs.writeText "quickshell-test-bar.qml" barContent;
          };
        in
        [
          (isShellPresent wrapper)
          (isBarPresent wrapper null)
          (isCorrectConfig wrapper)
        ];

      "wrapper should keep correct hierachy with component modules" =
        let
          wrapper = baseWrapper.wrap {
            configFile = "import qs.foo.boo\n" + shellContent;
            components.foo.boo.bar = barContent;
          };
        in
        [
          (isShellPresent wrapper)
          (isBarPresent wrapper "foo/boo")
          (isCorrectConfig wrapper)
        ];
    };
}
