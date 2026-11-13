{ wlib, lib, ... }:
{
  imports = [
    wlib.modules.symlinkScript
    wlib.modules.constructFiles
    wlib.modules.makeWrapper
    wlib.modules.stdenvPhases
  ];
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
