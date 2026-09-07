{
  config,
  lib,
  wlib,
  pkgs,
  ...
}:
let
  removeExt =
    s:
    let
      m = builtins.match "^(.*)\\.[^.]*$" s;
    in
    if m == null then s else builtins.elemAt m 0;
  isAlphaNum =
    v:
    let
      isUpper = c: c >= "A" && c <= "Z";
      isLower = c: c >= "a" && c <= "z";
      isDigit = c: c >= "0" && c <= "9";
    in
    isUpper v || isLower v || isDigit v || v == "_";
  sanitizeScriptName = lib.flip lib.pipe [
    baseNameOf
    removeExt
    lib.stringToCharacters
    (map (v: if isAlphaNum v then v else "_"))
    (builtins.concatStringsSep "")
  ];

  partitioned =
    let
      partitioned = wlib.partitionAttrs (
        name: v: builtins.isString (v.path.passthru.scriptName or null)
      ) (lib.filterAttrs (n: v: v.enable) config.script);
    in
    {
      nixpkgsScripts = lib.mapAttrsToList (n: v: v.path) partitioned.right;
      userScripts = partitioned.wrong;
    };
in
{
  imports = [ wlib.modules.default ];
  options = {
    script = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              enable = lib.mkEnableOption name // {
                default = true;
              };
              opts = lib.mkOption {
                type = lib.types.attrsOf (
                  lib.types.nullOr (
                    lib.types.oneOf [
                      lib.types.number
                      lib.types.bool
                      wlib.types.stringable
                    ]
                  )
                );
                default = { };
                description = ''
                  Script options passed via `--script-opts-append`.
                  Keys are prefixed with the sanitized script name.
                '';
              };
              path = lib.mkOption {
                type = lib.types.nullOr wlib.types.stringable;
                default = null;
                description = ''
                  Path to an existing script file.
                  Takes precedence over `content` if both are set.

                  If the value is a derivation with `passthru.scriptName` set,
                  it will assume this is a package from `pkgs.mpvScripts` and handle it accordingly.
                '';
              };
              content = lib.mkOption {
                type = lib.types.nullOr lib.types.lines;
                default = null;
                description = ''
                  Inline script file content.
                  Used when `path` is null.
                '';
              };
            };
          }
        )
      );
      default = { };
      description = ''
        MPV script files and their options.

        Each key is the script name (used for sanitized option prefixes).
        The `path` attribute specifies an existing script file (wins over content).
        The `content` attribute specifies inline script content.
        The `opts` attribute specifies script options passed via `--script-opts-append`.

        Usage example:
        ```nix
        script = {
          modernz = {
            path = pkgs.mpvScripts.modernz;
            opts = {
              window_top_bar = false;
            };
          };
          "visualizer.lua" = {
            path = pkgs.mpvScripts.visualizer + "/share/mpv/scripts/visualizer.lua";
            opts = {
              mode = "force";
            };
          };
          "my_script.lua".content = "print('hello world')";
        };
        ```
        This generates: `--script-opts-append=modernz_window_top_bar=false`
      '';
      example = lib.literalMD ''
        ```nix
        script = {
          modernz.path = pkgs.mpvScripts.modernz;
          modernz.opts = {
            window_top_bar = false;
            seekbarfg_color = "#FFFFFF";
          };
        };
        ```
      '';
    };
    "mpv.input" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedInput.path;
      };
      default = { };
      description = ''
        The MPV input configuration file.

        Provide `.content` to inline bindings or `.path` to use an existing `input.conf`.
        This file defines custom key bindings and command mappings.
        It is passed to MPV using `--input-conf`.
      '';
    };
    "mpv.conf" = lib.mkOption {
      type = wlib.types.file {
        path = lib.mkOptionDefault config.constructFiles.generatedConfig.path;
      };
      default = { };
      description = ''
        The main MPV configuration file.

        Provide `.content` to inline configuration options or `.path` to reference an existing `mpv.conf`.
        This file controls playback behavior, default options, video filters, and output settings.
        It is included by MPV using the `--include` flag.
      '';
    };
    configDir = lib.mkOption {
      type = lib.types.either wlib.types.stringable (
        lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                enable = lib.mkEnableOption name // {
                  default = true;
                };
                path = lib.mkOption {
                  type = lib.types.nullOr wlib.types.stringable;
                  default = null;
                  description = ''
                    Path to an existing config file.
                    Takes precedence over `content` if both are set.
                  '';
                };
                content = lib.mkOption {
                  type = lib.types.nullOr lib.types.lines;
                  default = null;
                  description = ''
                    Inline config file content.
                    Used when `path` is null.
                  '';
                };
              };
            }
          )
        )
      );
      default = { };
      description = ''
        Additional files to be included in the MPV config directory.

        By using this option, mpv will no longer look for script-opts in the default
        $XDG_CONFIG_HOME/mpv/script-opts location, and all additional files will have
        to be specified in this option.

        Each entry of the attrset is the relative path to the file and their content respectively.
      '';
      example = lib.literalMD ''
        ```nix
        {
          "script-opts/modernz.conf".content = '''
            window_top_bar=no
            seekbarfg_color=#FFFFFF
          ''';
        };
        ```
      '';
      apply =
        x:
        lib.warnIf (x ? "mpv.input" || x ? "mpv.conf")
          ''mpv.input is set via `config."mpv.input"`, not `config.configDir."mpv.input"`, and the same is true of `config."mpv.conf"` and `config.configDir."mpv.conf"`!''
          x;
    };
  };

  config.flagSeparator = "=";
  config.flags = {
    "--input-conf" = {
      data = config."mpv.input".path;
      sep = "=";
    };
    "--include" = lib.mkIf (config.configDir == { } || !builtins.isAttrs config.configDir) {
      data = [ config."mpv.conf".path ];
      sep = "=";
    };
    "--config-dir" = lib.mkIf (config.configDir != { }) (
      if !builtins.isAttrs config.configDir then
        config.configDir
      else
        dirOf config.constructFiles.generatedConfig.path
    );
  }
  // (
    let
      scriptsData = lib.pipe partitioned.userScripts [
        (lib.filterAttrs (n: v: v.path != null || v.content != null))
        (lib.mapAttrsToList (n: _: config.constructFiles."scripts/${n}".path))
      ];
      scriptOptsData = lib.concatMap (
        v:
        let
          sanitized = sanitizeScriptName v.name;
        in
        if v.value.opts == { } then
          [ ]
        else
          builtins.concatLists (
            lib.mapAttrsToList (
              k: v:
              if v == null then [ ] else [ "${sanitized}-${k}=${if lib.isStringLike v then v else toString v}" ]
            ) v.value.opts
          )
      ) (lib.mapAttrsToList lib.nameValuePair config.script);
    in
    {
      "--scripts-append" =
        lib.mkIf (scriptsData != [ ] && (config.configDir == { } || !builtins.isAttrs config.configDir))
          {
            sep = "=";
            ifs = null;
            data = scriptsData;
          };
      "--script-opts-append" = lib.mkIf (scriptOptsData != [ ]) {
        sep = "=";
        ifs = null;
        data = scriptOptsData;
      };
    }
  );

  config.constructFiles =
    lib.pipe config.configDir [
      (lib.filterAttrs (_: v: v.enable && (v.path != null || v.content != null)))
      (builtins.mapAttrs (
        name: v: {
          content = if builtins.isString (v.content or null) then v.content else "";
          output = lib.mkOverride 0 config.constructFiles.generatedConfig.output;
          relPath = lib.mkOverride 0 "${dirOf config.constructFiles.generatedConfig.relPath}/${name}";
          ${if v.path or null != null then "builder" else null} = ''ln -s "${v.path}" "$2"'';
        }
      ))
    ]
    // lib.pipe partitioned.userScripts [
      (lib.filterAttrs (_: v: v.path != null || v.content != null))
      (lib.mapAttrs' (
        name: v:
        lib.nameValuePair "scripts/${name}" {
          content = if builtins.isString (v.content or null) then v.content else "";
          output = lib.mkOverride 0 config.constructFiles.generatedConfig.output;
          relPath = lib.mkOverride 0 "${dirOf config.constructFiles.generatedConfig.relPath}/scripts/${name}";
          ${if v.path or null != null then "builder" else null} = ''ln -s "${v.path}" "$2"'';
        }
      ))
    ]
    // {
      generatedConfig = {
        relPath = "${config.binName}-config/mpv.conf";
        content = config."mpv.conf".content;
      };
      generatedInput = {
        relPath = lib.mkOverride 0 "${dirOf config.constructFiles.generatedConfig.relPath}/input.conf";
        output = lib.mkOverride 0 config.constructFiles.generatedConfig.output;
        content = config."mpv.input".content;
      };
    };

  config.passthru.generatedConfig = dirOf config.constructFiles.generatedConfig.outPath;

  config.overrides = lib.mkIf (partitioned.nixpkgsScripts or [ ] != [ ]) [
    {
      name = "MPV_SCRIPTS";
      type = "override";
      data = prev: {
        scripts = (prev.scripts or [ ]) ++ partitioned.nixpkgsScripts;
      };
    }
  ];
  config.package = lib.mkDefault pkgs.mpv;
  config.meta.maintainers = [ wlib.maintainers.birdee ];
}
