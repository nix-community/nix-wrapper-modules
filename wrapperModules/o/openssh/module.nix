{
  config,
  wlib,
  lib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = lib.types.string;
      default = "";
      description = ''
        OpenSSH client configuration settings.
        See `man 5 ssh_config`
      '';
      example = ''
        Host foo
          User bar
          HostName 192.168.0.2
          ProxyJump baz

        Host baz
          HostName 192.168.0.1
      '';
    };
  };

  config = {
    package = lib.mkDefault config.pkgs.openssh;
    flags = {
      "-F" = builtins.toString (config.pkgs.writeText "ssh-config" config.settings);
    };
    meta = {
      inherit (config.package) platforms;
      maintainers = [ wlib.maintainers.patwid ];
    };
  };
}
