{
  pkgs,
  self,
}:
let
  opensshWrapped = self.wrappedModules.openssh.wrap {
    inherit pkgs;

    settings = ''
      Host foo
        User bar
        HostName 192.168.0.2
        ProxyJump baz

      Host baz
        HostName 192.168.0.1
    '';
  };

in
if builtins.elem pkgs.stdenv.hostPlatform.system self.wrappedModules.openssh.meta.platforms then
  pkgs.runCommand "ssh-test" { } ''
    "${opensshWrapped}/bin/ssh" -G foo | grep -q 'HostName 192.168.0.2'
    touch $out
  ''
else
  null
