{
  config,
  lib,
  wlib,
  ...
}:
let
  description = ''
    Options for adding systemd unit files to the derivation for both user and system unit search paths.

    This does not add the derivation to the unit search path itself, it adds the unit files to the lib and share directories of the derivation.

    When installing in a target module system using the `config.install` module, the importable module will do this for you (for supported module systems).
    For example, in nixos, doing so will add the wrapper to `config.systemd.packages` alongside `environment.systemPackages`

    See `options.install.systemd` to control which module systems to install in.

    When using this module, the first time you install the derivation, systemd will not enable the service until you restart the system.

    You may start it manually by name, but systemd does not refresh its paths for `.wants`, `.requires`, and `.upholds` links unless restarted.

    However, for everything other than enablement, it will reflect updates by simply rebuilding with nixos or home manager,
    and it will continue to be automatically enabled as long as it keeps the same name.
  '';

  atom = lib.types.nullOr (
    lib.types.oneOf [
      lib.types.bool
      lib.types.float
      lib.types.int
      lib.types.str
    ]
  );
  sectionType = lib.types.attrsOf (lib.types.either (lib.types.listOf atom) atom);
  freeformType = lib.types.attrsOf sectionType;
  unitMod = {
    options = {
      Unit = lib.mkOption {
        type = lib.types.submodule {
          freeformType = sectionType;
          options = {
            Description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "A human-readable title for the unit.";
            };
            Documentation = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "URIs documenting the unit (http://, https://, man:, info:).";
            };
            Wants = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Weak requirement dependencies — listed units are started if possible.";
            };
            Requires = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Strong requirement dependencies — listed units must start or this unit fails.";
            };
            BindsTo = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Like Requires, but also stops this unit if the bound unit stops unexpectedly.";
            };
            Before = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Ordering: start before the listed units.";
            };
            After = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Ordering: start after the listed units.";
            };
            OnFailure = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Units activated when this unit enters failed state.";
            };
            Conflicts = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Negative dependency — cannot run alongside listed units.";
            };
            DefaultDependencies = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Whether to add implicit default dependencies.";
            };
            X-Reload-Triggers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "A list of values to watch for reload which, if changed between nixos generations, will cause the unit to be reloaded.";
            };
          };
        };
        default = { };
        description = ''
          [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)                
        '';
      };
    };
  };
  installMod = {
    options = {
      Install = lib.mkOption {
        type = lib.types.submodule {
          freeformType = sectionType;
          options = {
            WantedBy = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "A list of units that want this unit (adds Wants= dependency from them to this unit).";
            };
            RequiredBy = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "A list of units that require this unit (adds Requires= dependency from them to this unit).";
            };
            UpheldBy = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "A list of units that uphold this unit (adds Upholds= dependency from them to this unit).";
            };
          };
        };
        default = { };
        description = ''
          [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)                

          NOTE: nixos module configuration only cares about `WantedBy`, `UpheldBy`, and `RequiredBy` and ignores most other fields.
          However, manually enabling the option via `systemd enable <name>` will take this section into account as normal
        '';
      };
    };
  };
  systemdFileMods = {
    service = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
      options = {
        Service = lib.mkOption {
          description = ''
            [man systemd.service](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              Type = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.enum [
                    "simple"
                    "exec"
                    "forking"
                    "oneshot"
                    "dbus"
                    "notify"
                    "notify-reload"
                    "idle"
                  ]
                );
                default = null;
                description = "Startup notification type.";
              };
              ExecStart = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Main command(s) to execute when the service starts.";
              };
              ExecReload = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Command to reload the service configuration.";
              };
              ExecStop = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Command to stop the service.";
              };
              Restart = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.enum [
                    "no"
                    "on-success"
                    "on-failure"
                    "on-abnormal"
                    "on-watchdog"
                    "on-abort"
                    "always"
                  ]
                );
                default = null;
                description = "Restart condition for the service process.";
              };
              RestartSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Sleep duration before a restart attempt.";
              };
              User = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "The user to run the service as.";
              };
              Group = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "The group to run the service as.";
              };
              WorkingDirectory = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Working directory for the service process.";
              };
              Environment = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Environment variables to set for the service.";
              };
              StandardOutput = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Where to connect standard output (journal, syslog, null, tty, ...).";
              };
              StandardError = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Where to connect standard error (journal, syslog, null, tty, ...).";
              };
              X-ReloadIfChanged = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = null;
                description = "Whether to reload the service when its unit file changes.";
              };
            };
          };
        };
      };
    };
    socket = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
      options = {
        Socket = lib.mkOption {
          description = ''
            [man systemd.socket](https://www.freedesktop.org/software/systemd/man/latest/systemd.socket.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              ListenStream = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "TCP or UNIX stream socket address to listen on.";
              };
              ListenDatagram = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "UDP or UNIX datagram socket address to listen on.";
              };
              ListenFIFO = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Named pipe (FIFO) path to listen on.";
              };
              Accept = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to accept one connection per service instance.";
              };
              Backlog = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "The listen() backlog number.";
              };
              SocketUser = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Owner of the UNIX socket inode.";
              };
              SocketGroup = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Group of the UNIX socket inode.";
              };
              SocketMode = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Permissions of the UNIX socket (e.g. 0666).";
              };
              Service = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Unit name activated by this socket.";
              };
              RemoveOnStop = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to remove the socket/FIFO when the unit stops.";
              };
            };
          };
        };
      };
    };
    device = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
    };
    mount = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
      options = {
        Mount = lib.mkOption {
          description = ''
            [man systemd.mount](https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              What = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Device node, filesystem label, UUID, or path to mount.";
              };
              Where = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Absolute mount point path (must match unit filename).";
              };
              Type = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Filesystem type string (e.g. ext4, xfs, btrfs).";
              };
              Options = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Comma-separated mount options.";
              };
              DirectoryMode = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Permissions for auto-created mount point directories (e.g. 0755).";
              };
              TimeoutSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Maximum time to wait for the mount command to finish.";
              };
            };
          };
        };
      };
    };
    automount = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
      options = {
        Automount = lib.mkOption {
          description = ''
            [man systemd.automount](https://www.freedesktop.org/software/systemd/man/latest/systemd.automount.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              Where = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Absolute automount point path (must match unit filename).";
              };
              DirectoryMode = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Permissions for auto-created automount point directories (e.g. 0755).";
              };
              TimeoutIdleSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Idle time after which systemd attempts to unmount.";
              };
            };
          };
        };
      };
    };
    swap = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
      options = {
        Swap = lib.mkOption {
          description = ''
            [man systemd.swap](https://www.freedesktop.org/software/systemd/man/latest/systemd.swap.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              What = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Device node, file, or fstab-style identifier for the swap device.";
              };
              Priority = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Swap priority.";
              };
              Options = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Comma-separated swapon options (e.g. discard).";
              };
              TimeoutSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Maximum time to wait for swapon to finish.";
              };
            };
          };
        };
      };
    };
    target = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
    };
    path = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
      options = {
        Path = lib.mkOption {
          description = ''
            [man systemd.path](https://www.freedesktop.org/software/systemd/man/latest/systemd.path.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              PathExists = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Activate the unit when a file or directory exists.";
              };
              PathExistsGlob = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Activate when at least one file matching the glob exists.";
              };
              PathChanged = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Activate when a file changes (triggers on close-after-write).";
              };
              PathModified = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Activate on any write to the file.";
              };
              DirectoryNotEmpty = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Activate when a directory contains at least one entry.";
              };
              Unit = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Unit to activate when a path triggers (defaults to the matching .service unit).";
              };
              MakeDirectory = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Create the watched directories before monitoring.";
              };
              DirectoryMode = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Permissions for auto-created directories (e.g. 0755).";
              };
            };
          };
        };
      };
    };
    timer = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
      options = {
        Timer = lib.mkOption {
          description = ''
            [man systemd.timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              OnActiveSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Timer relative to when this timer unit was activated.";
              };
              OnBootSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Timer relative to boot time.";
              };
              OnStartupSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Timer relative to when the service manager started.";
              };
              OnUnitActiveSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Timer relative to when the triggered unit was last activated.";
              };
              OnUnitInactiveSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Timer relative to when the triggered unit was last deactivated.";
              };
              OnCalendar = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Realtime (wallclock) calendar event expression.";
              };
              AccuracySec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Scheduling accuracy window (default 1min).";
              };
              RandomizedDelaySec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Random delay added to each timer firing.";
              };
              Unit = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Unit to activate when the timer elapses (defaults to the matching .service unit).";
              };
              Persistent = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Catch up on missed OnCalendar= firings after boot.";
              };
              WakeSystem = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Wake the system from suspend to meet the timer deadline.";
              };
            };
          };
        };
      };
    };
    slice = {
      inherit freeformType;
      imports = [
        unitMod
        installMod
      ];
      options = {
        Slice = lib.mkOption {
          description = ''
            [man systemd.slice](https://www.freedesktop.org/software/systemd/man/latest/systemd.slice.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              ConcurrencyHardMax = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.int (lib.types.enum [ "infinity" ]));
                default = null;
                description = ''
                  Hard limit on the number of active units within this slice and all descendant slices.

                  When the limit is reached, activation of additional units fails immediately.
                  Use "infinity" to disable the limit.
                '';
              };
              ConcurrencySoftMax = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.int (lib.types.enum [ "infinity" ]));
                default = null;
                description = ''
                  Soft limit on the number of active units within this slice and all descendant slices.

                  When the limit is reached, additional unit activations are queued until the
                  number of active units falls below the limit. Use "infinity" to disable the limit.
                '';
              };
            };
          };
        };
      };
    };
    scope = {
      inherit freeformType;
      imports = [ unitMod ];
      options = {
        Scope = lib.mkOption {
          description = ''
            [man systemd.scope](https://www.freedesktop.org/software/systemd/man/latest/systemd.scope.html)
          '';
          type = lib.types.submodule {
            freeformType = sectionType;
            options = {
              OOMPolicy = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.enum [
                    "continue"
                    "stop"
                    "kill"
                  ]
                );
                default = null;
                description = "OOM killer behavior for the scope.";
              };
              RuntimeMaxSec = lib.mkOption {
                type = lib.types.nullOr (lib.types.either lib.types.str lib.types.number);
                default = null;
                description = "Maximum time the scope may be active (e.g. 1h, 30m).";
              };
            };
          };
        };
      };
    };
  };
  extensionsSubmodule = { name, ... }: {
    options =
      let
        extraMod = { _prefix, ... }: {
          options =
            let
              # id is just a nice looking name for documentation purposes such as "user <name>.service"
              id =
                if builtins.length _prefix >= 3 then
                  let
                    get = builtins.elemAt (lib.takeEnd 3 _prefix);
                  in
                  "${get 0} ${get 2}.${get 1}"
                else
                  "systemd";
            in
            {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable generation of ${id} unit file.";
              };
              doInstall = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = ''
                  Create .wants .requires and .upholds links for ${id} unit.
                  (This will enable the service file automatically on next restart if the derivation ends up in your systemd unit search path.)
                '';
              };
              overwrite = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Overwrite existing unit file instead of appending generated content to it if present.";
              };
              prefixedContent = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = "Content to prepend to the beginning of the generated ${id} unit file.";
              };
              suffixedContent = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = "Content to append to the end of the generated ${id} unit file.";
              };
            };
        };
      in
      {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable generation of systemd ${name} units.";
        };
        service = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.service
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts a `Service` section:
            [man systemd.service](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)

            Also accepts the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        socket = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.socket
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts a `Socket` section:
            [man systemd.socket](https://www.freedesktop.org/software/systemd/man/latest/systemd.socket.html)

            Also accepts the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        device = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.device
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            [man systemd.device](https://www.freedesktop.org/software/systemd/man/latest/systemd.device.html)

            Accepts only the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        mount = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.mount
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts a `Mount` section:
            [man systemd.mount](https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html)

            Also accepts the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        automount = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.automount
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts an `Automount` section:
            [man systemd.automount](https://www.freedesktop.org/software/systemd/man/latest/systemd.automount.html)

            Also accepts the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        swap = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.swap
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts a `Swap` section:
            [man systemd.swap](https://www.freedesktop.org/software/systemd/man/latest/systemd.swap.html)

            Also accepts the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        target = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.target
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            [man systemd.target](https://www.freedesktop.org/software/systemd/man/latest/systemd.target.html)

            Accepts only the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        path = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.path
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts a `Path` section:
            [man systemd.path](https://www.freedesktop.org/software/systemd/man/latest/systemd.path.html)

            Also accepts the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        timer = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.timer
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts a `Timer` section:
            [man systemd.timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)

            Also accepts the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        slice = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.slice
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts a `Slice` section:
            [man systemd.slice](https://www.freedesktop.org/software/systemd/man/latest/systemd.slice.html)

            Also accepts the general `Unit` or `Install` sections:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
        scope = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              imports = [
                systemdFileMods.scope
                extraMod
              ];
            }
          );
          default = { };
          description = ''
            Accepts a `Scope` section:
            [man systemd.scope](https://www.freedesktop.org/software/systemd/man/latest/systemd.scope.html)

            Also accepts the general `Unit` section, but NOT the `Install` section:
            [man systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
          '';
        };
      };
  };
in
{
  imports = [
    ./config.nix
  ];
  config.meta.maintainers = [ wlib.maintainers.birdee ];
  config.meta.description = description;
  options.install.systemd = lib.mkOption {
    type = lib.types.listOf (
      lib.types.enum [
        "nixos"
        "homeManager"
        "hjem"
      ]
    );
    default = [
      "nixos"
      "homeManager"
      "hjem"
    ];
    description = "Add the service files specified by `options.systemd` in the derivation to the specified module systems via the install module";
  };
  # systemd.<name>.{user, system}.{target, path, timer, service, socket, scope, device, mount, automount, swap, path, slice}.{ relevant filemod + enable, install fields }
  options.systemd = lib.mkOption {
    description = description;
    default = { };
    type = lib.types.submodule {
      options = {
        user = lib.mkOption {
          type = lib.types.submodule extensionsSubmodule;
          default = { };
          description = ''
            Options for defining user-level systemd unit files.
          '';
        };
        system = lib.mkOption {
          type = lib.types.submodule extensionsSubmodule;
          default = { };
          description = ''
            Options for defining system-level systemd unit files.
          '';
        };
      };
    };
  };
}
