{
  pkgs,
  self,
  tlib,
  lib,
  ...
}:

let
  inherit (tlib)
    areEqual
    test
    fileContains
    isFile
    ;

  evalWith =
    extraConfig:
    (self.lib.evalModule [
      { inherit pkgs; }
      (
        {
          config,
          lib,
          wlib,
          ...
        }:
        {
          imports = [ wlib.modules.systemd ];
          package = pkgs.hello;
        }
      )
      extraConfig
    ]).config;

  evalWrapper = extraConfig: (evalWith extraConfig).wrapper;

  # Service file naming: lib/systemd/<type>/<name>.<ext>
  unitPath =
    wrapper: type: ext: name:
    "${wrapper}/lib/systemd/${type}/${name}.${ext}";
  linkPath =
    wrapper: type: ext: name:
    "${wrapper}/share/systemd/${type}/${name}.${ext}";
in
test "systemd" {
  ##############################################################################
  # Unit keys exist in drv
  ##############################################################################
  "drv keys" =
    let
      cfg = evalWith (
        {
          config,
          lib,
          wlib,
          ...
        }:
        {
          config.systemd.user = {
            service.svc = {
              Service.ExecStart = "/bin/true";
            };
            socket.sck = {
              Socket.ListenStream = [ "/run/x.sock" ];
            };
            timer.tmr = {
              Timer.OnCalendar = [ "daily" ];
            };
            target.tgt = { };
            path.pth = {
              Path.PathExists = [ "/tmp" ];
            };
            device.dev = { };
            mount.mnt = {
              Mount.What = "/dev/sda1";
              Mount.Where = "/mnt";
            };
            automount.aut = {
              Automount.Where = "/mnt";
            };
            swap.swp = {
              Swap.What = "/swapfile";
            };
            slice.slc = { };
            scope.scp = { };
          };
          config.systemd.system.service."sys-svc" = {
            Service.ExecStart = "/bin/system";
          };
        }
      );
      keys = [
        "systemd_user_service_svc"
        "systemd_user_socket_sck"
        "systemd_user_timer_tmr"
        "systemd_user_target_tgt"
        "systemd_user_path_pth"
        "systemd_user_device_dev"
        "systemd_user_mount_mnt"
        "systemd_user_automount_aut"
        "systemd_user_swap_swp"
        "systemd_user_slice_slc"
        "systemd_user_scope_scp"
        "systemd_system_service_sys_svc"
      ];
    in
    map (k: {
      cond = if cfg.drv ? ${k} then "true" else "false";
      msg = "drv key '${k}' not found in cfg.drv";
    }) keys;

  ##############################################################################
  # Content of actual generated files in lib/systemd/<type>
  ##############################################################################
  "content" =
    let
      wrapper = evalWrapper (
        {
          config,
          lib,
          wlib,
          ...
        }:
        {
          config.systemd.user.service."test" = {
            Unit.Description = "test service";
            Service.Type = "simple";
            Service.ExecStart = "/bin/true";
            Install.WantedBy = [ "multi-user.target" ];
          };
          config.systemd.user.socket."sock" = {
            Socket.ListenStream = [ "/run/test.sock" ];
            Install.WantedBy = [ "sockets.target" ];
          };
          config.systemd.user.timer."tmr" = {
            Timer.OnCalendar = [ "daily" ];
          };
          config.systemd.user.path."p" = {
            Path.PathExists = [ "/tmp/test" ];
          };
        }
      );
      svcFile = unitPath wrapper "user" "service" "test";
      sockFile = unitPath wrapper "user" "socket" "sock";
      tmrFile = unitPath wrapper "user" "timer" "tmr";
      pthFile = unitPath wrapper "user" "path" "p";
      svcLink = linkPath wrapper "user" "service" "test";
      sockLink = linkPath wrapper "user" "socket" "sock";
      tmrLink = linkPath wrapper "user" "timer" "tmr";
      pthLink = linkPath wrapper "user" "path" "p";
    in
    {
      "sections" = [
        (isFile svcFile)
        (fileContains svcFile "\\[Unit\\]")
        (fileContains svcFile "\\[Service\\]")
        (fileContains svcFile "\\[Install\\]")
      ];
      "service key-values" = [
        (fileContains svcFile "Description=test service")
        (fileContains svcFile "Type=simple")
        (fileContains svcFile "ExecStart=/bin/true")
        (fileContains svcFile "WantedBy=multi-user.target")
      ];
      "socket key-values" = [
        (isFile sockFile)
        (fileContains sockFile "ListenStream=/run/test.sock")
        (fileContains sockFile "WantedBy=sockets.target")
      ];
      "timer key-values" = [
        (isFile tmrFile)
        (fileContains tmrFile "OnCalendar=daily")
      ];
      "path key-values" = [
        (isFile pthFile)
        (fileContains pthFile "PathExists=/tmp/test")
      ];
      "symlinks in share" = [
        (isFile svcLink)
        (isFile sockLink)
        (isFile tmrLink)
        (isFile pthLink)
      ];
    };

  ##############################################################################
  # Enable/disable filtering
  ##############################################################################
  "enable/disable" = {
    "individual unit" =
      let
        cfg = evalWith (
          {
            config,
            lib,
            wlib,
            ...
          }:
          {
            config.systemd.user.service."disabled" = {
              enable = false;
            };
            config.systemd.user.service."enabled" = {
              Service.ExecStart = "/bin/true";
            };
          }
        );
      in
      [
        (areEqual (cfg.drv ? systemd_user_service_disabled) false)
        (areEqual (cfg.drv ? systemd_user_service_enabled) true)
      ];

    "extension type" =
      let
        cfg = evalWith (
          {
            config,
            lib,
            wlib,
            ...
          }:
          {
            config.systemd.user = {
              enable = false;
              service.svc = {
                Service.ExecStart = "/bin/true";
              };
            };
          }
        );
      in
      [
        (areEqual (cfg.drv ? systemd_user_service_svc) false)
      ];

    "system scope" =
      let
        cfg = evalWith (
          {
            config,
            lib,
            wlib,
            ...
          }:
          {
            config.systemd.system = {
              enable = false;
              service.svc = {
                Service.ExecStart = "/bin/true";
              };
            };
            config.systemd.user.service."svc" = {
              Service.ExecStart = "/bin/true";
            };
          }
        );
      in
      [
        (areEqual (cfg.drv ? systemd_system_service_svc) false)
        (areEqual (cfg.drv ? systemd_user_service_svc) true)
      ];
  };

  ##############################################################################
  # Section validation
  ##############################################################################
  "section validation" = {
    "invalid sections throw" =
      let
        cfg = evalWith (
          {
            config,
            lib,
            wlib,
            ...
          }:
          {
            config.systemd.user.service."bad" = {
              InvalidSection = {
                foo = "bar";
              };
            };
          }
        );
        result = builtins.tryEval cfg.drv.systemd_user_service_bad;
      in
      [
        (areEqual result.success false)
      ];

    "X- custom sections" =
      let
        cfg = evalWith (
          {
            config,
            lib,
            wlib,
            ...
          }:
          {
            config.systemd.user.service."test" = {
              "X-Custom" = {
                foo = "bar";
              };
              Service.ExecStart = "/bin/true";
            };
          }
        );
      in
      [
        (areEqual (cfg.drv ? systemd_user_service_test) true)
      ];
  };

  ##############################################################################
  # Value handling - check actual file output
  ##############################################################################
  ##############################################################################
  # Merging with existing files from the wrapped package
  ##############################################################################
  "merges with existing unit files" =
    let
      wrapper = self.lib.evalPackage [
        { inherit pkgs; }
        (
          {
            config,
            lib,
            wlib,
            pkgs,
            ...
          }:
          {
            imports = [
              wlib.modules.systemd
              wlib.modules.default
            ];
            package = pkgs.runCommand "test-pkg" { } ''
              mkdir -p $out/lib/systemd/user
              cat > $out/lib/systemd/user/test.service <<'EOF'
              [Unit]
              Description=original service

              [Service]
              ExecStart=/bin/original
              EOF
              mkdir -p $out/bin
              echo "# placeholder" > $out/bin/test-pkg
              chmod +x $out/bin/test-pkg
            '';
            systemd.user.service."test" = {
              Service.ExecStart = "/bin/additional";
              Install.WantedBy = [ "multi-user.target" ];
            };
            systemd.system.service."sys" = {
              Service.ExecStart = "/bin/system-svc";
            };
          }
        )
      ];
      svcFile = unitPath wrapper "user" "service" "test";
      sysFile = unitPath wrapper "system" "service" "sys";
      svcLink = linkPath wrapper "user" "service" "test";
    in
    [
      (isFile svcFile)
      (fileContains svcFile "Description=original service")
      (fileContains svcFile "ExecStart=/bin/original")
      (fileContains svcFile "ExecStart=/bin/additional")
      (fileContains svcFile "WantedBy=multi-user.target")
      (isFile sysFile)
      (fileContains sysFile "ExecStart=/bin/system-svc")
      (isFile svcLink)
    ];

  ##############################################################################
  # overwrite option replaces existing file instead of merging
  ##############################################################################
  "overwrite replaces existing" =
    let
      basePkg = pkgs.runCommand "test-pkg-overwrite" { } ''
        mkdir -p $out/lib/systemd/user
        cat > $out/lib/systemd/user/test.service <<'EOF'
        [Unit]
        Description=original service
        EOF
        mkdir -p $out/bin
        echo "# placeholder" > $out/bin/test-pkg-overwrite
        chmod +x $out/bin/test-pkg-overwrite
      '';
      wrapper =
        (self.lib.evalModule [
          { inherit pkgs; }
          (
            {
              config,
              lib,
              wlib,
              ...
            }:
            {
              imports = [
                wlib.modules.default
                wlib.modules.systemd
              ];
              package = basePkg;
            }
          )
          {
            config.systemd.user.service."test" = {
              overwrite = true;
              Service.ExecStart = "/bin/only-this";
            };
          }
        ]).config.wrapper;
      svcFile = unitPath wrapper "user" "service" "test";
    in
    [
      (isFile svcFile)
      (fileContains svcFile "ExecStart=/bin/only-this")
      {
        cond = "! grep -q 'Description=original' ${svcFile}";
        msg = "overwrite=true should not contain original content";
      }
    ];

  "value handling" = {
    "null" =
      let
        wrapper = evalWrapper (
          {
            config,
            lib,
            wlib,
            ...
          }:
          {
            config.systemd.user.service."test" = {
              Service.Type = null;
            };
          }
        );
        servicepath = (unitPath wrapper "user" "service" "test");
      in
      [
        (isFile servicepath)
        (fileContains servicepath "# Type is unset")
      ];

    "duplicate list keys" =
      let
        wrapper = evalWrapper (
          {
            config,
            lib,
            wlib,
            ...
          }:
          {
            config.systemd.user.service."test" = {
              Service.Environment = [
                "FOO=bar"
                "BAZ=qux"
              ];
            };
          }
        );
        servicepath = (unitPath wrapper "user" "service" "test");
      in
      [
        (fileContains servicepath "Environment=FOO=bar")
        (fileContains servicepath "Environment=BAZ=qux")
      ];
  };

  ##############################################################################
  # passAsFile
  ##############################################################################
  "passAsFile" =
    let
      cfg = evalWith (
        {
          config,
          lib,
          wlib,
          ...
        }:
        {
          config.systemd.user.service."a" = {
            Service.ExecStart = "/bin/a";
          };
          config.systemd.user.service."b" = {
            Service.ExecStart = "/bin/b";
          };
        }
      );
      expected = [
        "systemd_user_service_a"
        "systemd_user_service_b"
      ];
    in
    [
      (areEqual (builtins.sort builtins.lessThan cfg.drv.passAsFile) (
        builtins.sort builtins.lessThan expected
      ))
    ];
}
