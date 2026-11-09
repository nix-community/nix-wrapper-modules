{
  config,
  lib,
  wlib,
  ...
}:
let
  defaultPhases = [
    "buildPhase"
    "checkPhase"
    "installPhase"
    "installCheckPhase"
    "distPhase"
  ];
  setupPhases =
    phases:
    let
      capitalize =
        s:
        let
          first = builtins.substring 0 1 s;
          rest = builtins.substring 1 (builtins.stringLength s - 1) s;
        in
        lib.strings.toUpper first + rest;
      final_phases = if builtins.isList phases then phases else defaultPhases;
    in
    (lib.pipe final_phases [
      (builtins.concatMap (
        n:
        lib.optionals (builtins.isString n && lib.isValidPosixName n) [
          "\${pre${capitalize n}s[*]:-}"
          "${n}"
        ]
      ))
      (v: [ "\${prePhases[*]:-}" ] ++ v ++ [ "\${postPhases[*]:-}" ])
      (builtins.concatStringsSep " ")
      (v: "\n" + ''phases="${v}"'' + "\n")
    ]);
in
{
  options.sourceStdenv = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Run the enabled stdenv phases on the wrapper derivation.
    '';
  };
  config.drv.phases = lib.mkOptionDefault defaultPhases;
  config.buildCommand.runStdenvPhases = {
    after = [
      "makeWrapper"
      "constructFiles"
      "symlinkScript"
      "systemd"
      "setupStdenvPhases"
    ];
    data = lib.mkOptionDefault (
      lib.optionalString config.sourceStdenv ''
        for curPhase in ''${phases[*]}; do
            runPhase "$curPhase"
        done
      ''
    );
  };
  config.buildCommand.setupStdenvPhases = {
    before = [
      "makeWrapper"
      "constructFiles"
      "symlinkScript"
      "systemd"
      "runStdenvPhases"
    ];
    data = lib.mkOptionDefault (lib.optionalString config.sourceStdenv (setupPhases config.drv.phases));
  };
  config.drv.buildPhase = lib.mkOptionDefault ''
    runHook preBuild
    runHook postBuild
  '';
  config.drv.installPhase = lib.mkOptionDefault ''
    runHook preInstall
    runHook postInstall
  '';
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config.meta.description = ''
    Runs the stdenv derivation phases, set via `config.drv`

    The enabled phases are controlled via `config.drv.phases`,
    and the other `config.drv` attributes.

    The `stdenvPhases` module creates the phases variable via `config.buildCommand.setupStdenvPhases`,
    and then runs them via `config.buildCommand.runStdenvPhases`,
    and you may run commands before or after this using the `config.buildCommand` DAG.

    Imported by `wlib.modules.default`
  '';
}
