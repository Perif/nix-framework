{ lib, pkgs, ... }:

let
  # Build 4205 ships two plug-in hosts. Only the legacy Python 3.3 host links
  # to OpenSSL 1.1; the Python 3.14 host uses OpenSSL 3. Replace the broad
  # Nixpkgs rpath input and remove the legacy host so old plug-ins fail closed
  # instead of restoring an end-of-life cryptographic library.
  sublimeTextBase = pkgs.sublime4-dev.override {
    openssl_1_1 = pkgs.openssl_3_5;
  };

  sublimeTextUnwrapped = sublimeTextBase.unwrapped.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      rm -f "$out/plugin_host-3.3" "$out/Lib/python3.3.zip"
    '';
  });

  sublimeTextSecure = pkgs.stdenvNoCC.mkDerivation {
    pname = "sublimetext4-secure";
    inherit (sublimeTextBase) version;

    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/share/applications"
      makeWrapper "${sublimeTextUnwrapped}/sublime_text" "$out/bin/sublime_text"
      ln -s sublime_text "$out/bin/subl"
      ln -s sublime_text "$out/bin/sublime"
      ln -s sublime_text "$out/bin/sublime4"

      substitute \
        "${sublimeTextUnwrapped}/sublime_text.desktop" \
        "$out/share/applications/sublime_text.desktop" \
        --replace-fail "/opt/sublime_text/sublime_text" "sublime_text"

      for directory in ${sublimeTextUnwrapped}/Icon/*; do
        size="$(basename "$directory")"
        mkdir -p "$out/share/icons/hicolor/$size/apps"
        ln -s "$directory"/* "$out/share/icons/hicolor/$size/apps/"
      done

      runHook postInstall
    '';

    passthru.unwrapped = sublimeTextUnwrapped;

    meta = sublimeTextBase.meta // {
      description = "Sublime Text with the legacy OpenSSL 1.1 plug-in host removed";
      longDescription = ''
        Sublime Text build 4205 using its Python 3.14 plug-in host and OpenSSL
        3. The obsolete Python 3.3 plug-in host is intentionally unavailable.
      '';
    };
  };
in
{
  assertions = [
    {
      assertion = lib.versionAtLeast sublimeTextBase.version "4205";
      message = "Secure Sublime packaging requires build 4205 or newer with the Python 3.14 plug-in host.";
    }
  ];

  home.packages = [
    sublimeTextSecure
    pkgs.sublime-merge
  ];

  xdg.configFile = {
    "sublime-text/Packages/User/Preferences.sublime-settings".text = ''
      {
        "font_face": "JetBrainsMono Nerd Font",
        "font_size": 10,
        "hardware_acceleration": "opengl",
        "update_check": false,

        "atomic_save": true,
        "auto_complete": true,
        "auto_complete_delay": 50,
        "detect_indentation": true,
        "translate_tabs_to_spaces": true,
        "tab_size": 4,
        "ensure_newline_at_eof_on_save": true,
        "trim_trailing_white_space_on_save": true,
        "draw_white_space": "selection",
        "highlight_line": true,
        "rulers": [88, 100],
        "save_on_focus_lost": false,

        "index_files": true,
        "folder_exclude_patterns": [
          ".git",
          ".direnv",
          ".venv",
          "__pycache__",
          "node_modules",
          "result",
          "target"
        ],
        "file_exclude_patterns": [
          "*.pyc",
          "*.pyo",
          "*.class"
        ],

        "lsp_format_on_save": true,
        "lsp_code_actions_on_save": {
          "source.fixAll": true,
          "source.organizeImports": true
        }
      }
    '';

    # Package Control itself is installed once through Sublime's built-in
    # installer. This seeds a small package set, not an enforced allowlist;
    # extra manual installs and upstream executable-code updates remain possible. Nix
    # owns every language-server binary and its absolute command below.
    "sublime-text/Packages/User/Package Control.sublime-settings".text = ''
      {
        "debug": false,
        "submit_usage": false,
        "auto_upgrade": true,
        "auto_upgrade_frequency": 24,
        "install_missing": true,
        "install_prereleases": [],
        "repositories": [],
        "channels": ["https://packagecontrol.io/channel_v3.json"],
        "installed_packages": [
          "EditorConfig",
          "LSP",
          "Nix",
          "Package Control"
        ]
      }
    '';

    "sublime-text/Packages/User/LanguageServers.sublime-settings".text = ''
      {
        "basedpyright": {
          "enabled": true,
          "command": ["${pkgs.basedpyright}/bin/basedpyright-langserver", "--stdio"],
          "selector": "source.python",
          "diagnostics_mode": "workspace",
          "settings": {
            "basedpyright": {
              "disableOrganizeImports": true,
              "analysis": {
                "diagnosticMode": "openFilesOnly",
                "typeCheckingMode": "basic"
              }
            }
          }
        },
        "ruff": {
          "enabled": true,
          "command": ["${pkgs.ruff}/bin/ruff", "server"],
          "selector": "source.python",
          "diagnostics_mode": "workspace"
        },
        "gopls": {
          "enabled": true,
          "command": ["${pkgs.gopls}/bin/gopls"],
          "selector": "source.go",
          "diagnostics_mode": "workspace",
          "settings": {
            "gopls": {
              "gofumpt": true,
              "staticcheck": true,
              "usePlaceholders": true
            }
          }
        },
        "rust-analyzer": {
          "enabled": true,
          "command": ["${pkgs.rust-analyzer}/bin/rust-analyzer"],
          "selector": "source.rust",
          "diagnostics_mode": "workspace",
          "settings": {
            "rust-analyzer": {
              "check": { "command": "clippy" },
              "cargo": { "buildScripts": { "enable": true } },
              "procMacro": { "enable": true }
            }
          }
        },
        "nixd": {
          "enabled": true,
          "command": ["${pkgs.nixd}/bin/nixd"],
          "selector": "source.nix",
          "diagnostics_mode": "workspace",
          "settings": {
            "nixd": {
              "formatting": {
                "command": ["${pkgs.nixfmt}/bin/nixfmt"]
              }
            }
          }
        }
      }
    '';

    "sublime-merge/Packages/User/Preferences.sublime-settings".text = ''
      {
        "font_face": "JetBrainsMono Nerd Font",
        "font_size": 10,
        "hardware_acceleration": "opengl",
        "update_check": false
      }
    '';
  };
}
