{
  lib,
  pkgs,
  nixpkgs-sublime,
  settings,
  ...
}:

let
  languages = settings.features.languageTools;
  # A separately locked Nixpkgs input keeps proprietary Sublime releases
  # current without advancing the whole operating-system package set.
  sublimePkgs = import nixpkgs-sublime {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  sublimeTextBase = sublimePkgs.sublime4;

  sublimeTextUnwrapped = sublimeTextBase.unwrapped.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      test -x "$out/plugin_host-3.14"
      rm -f "$out/plugin_host-3.3" "$out/Lib/python3.3.zip"
      # Fail a future packaging change that reintroduces the obsolete crypto
      # dependency in one of the surviving ELF binaries or bundled Python.
      test ! -e "$out/libssl.so.1.1"
      test ! -e "$out/libcrypto.so.1.1"
      for binary in sublime_text plugin_host-3.14 crash_handler libpython3.14.so.1.0; do
        needed="$(${pkgs.binutils}/bin/readelf -d "$out/$binary")"
        if printf '%s\n' "$needed" | grep -Eq 'NEEDED.*lib(ssl|crypto)\.so\.1\.1'; then
          echo "Unexpected OpenSSL 1.1 dependency in $binary" >&2
          exit 1
        fi
      done
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
      # Sublime's Linux menu bar is GTK-native rather than controlled by the
      # .sublime-theme. Force KDE's dark GTK theme for the launcher and CLI.
      makeWrapper "${sublimeTextUnwrapped}/sublime_text" "$out/bin/sublime_text" \
        --set GTK_THEME "Breeze-Dark"
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
        Sublime Text stable build ${sublimeTextBase.version} using its Python 3.14 plug-in host and OpenSSL
        3. The obsolete Python 3.3 plug-in host is intentionally unavailable.
      '';
    };
  };

  languageServers =
    lib.optionalAttrs languages.python {
      basedpyright = {
        enabled = true;
        command = [
          "${pkgs.basedpyright}/bin/basedpyright-langserver"
          "--stdio"
        ];
        selector = "source.python";
        diagnostics_mode = "workspace";
        settings.basedpyright = {
          disableOrganizeImports = true;
          analysis = {
            diagnosticMode = "openFilesOnly";
            typeCheckingMode = "basic";
          };
        };
      };
      ruff = {
        enabled = true;
        command = [
          "${pkgs.ruff}/bin/ruff"
          "server"
        ];
        selector = "source.python";
        diagnostics_mode = "workspace";
      };
    }
    // lib.optionalAttrs languages.go {
      gopls = {
        enabled = true;
        command = [ "${pkgs.gopls}/bin/gopls" ];
        selector = "source.go";
        diagnostics_mode = "workspace";
        settings.gopls = {
          gofumpt = true;
          staticcheck = true;
          usePlaceholders = true;
        };
      };
    }
    // lib.optionalAttrs languages.rust {
      "rust-analyzer" = {
        enabled = true;
        command = [ "${pkgs.rust-analyzer}/bin/rust-analyzer" ];
        selector = "source.rust";
        diagnostics_mode = "workspace";
        settings."rust-analyzer" = {
          check.command = "clippy";
          cargo.buildScripts.enable = true;
          procMacro.enable = true;
        };
      };
    }
    // {
      terraform-ls = {
        enabled = true;
        command = [ "${pkgs.terraform-ls}/bin/terraform-ls" "serve" ];
        selector = "source.terraform";
        diagnostics_mode = "workspace";
      };
    }
    // lib.optionalAttrs languages.nix {
      nixd = {
        enabled = true;
        command = [ "${pkgs.nixd}/bin/nixd" ];
        selector = "source.nix";
        diagnostics_mode = "workspace";
        settings.nixd.formatting.command = [ "${pkgs.nixfmt}/bin/nixfmt" ];
      };
    };
in
{
  assertions = [
    {
      assertion = lib.versionAtLeast sublimeTextBase.version "4213";
      message = "Secure Sublime packaging requires stable build 4213 or newer with the Python 3.14 plug-in host.";
    }
  ];

  home.packages = [
    sublimeTextSecure
    sublimePkgs.sublime-merge
  ];

  xdg.configFile = {
    "sublime-text/Packages/User/Preferences.sublime-settings".text = ''
      {
        "font_face": "JetBrainsMono Nerd Font",
        "font_size": 10,
        "hardware_acceleration": "opengl",
        "theme": "ayu-mirage.sublime-theme",
        "color_scheme": "ayu/ayu-mirage.sublime-color-scheme",
        "themed_title_bar": true,
        "file_icons": true,
        "update_check": false,
        "disable_plugin_host_3.3": true,

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
          "Package Control",
          "BracketHighlighter",
          "SublimeLinter",
          "SublimeCodeIntel",
          "AutoFileName",
          "All Autocomplete",
          "AdvancedNewFile",
          "MarkdownEditing",
          "ayu",
          "AlignTab",
          "AutoPEP8",
          "Formatter",
          "Formatter",
          "SideBarEnhancements"
        ]
      }
    '';

    "sublime-text/Packages/User/LanguageServers.sublime-settings".text =
      builtins.toJSON languageServers;

    "sublime-merge/Packages/User/Preferences.sublime-settings".text = ''
      {
        "font_face": "JetBrainsMono Nerd Font",
        "font_size": 10,
        "hardware_acceleration": "opengl",
        "theme": "Merge Dark.sublime-theme",
        "color_scheme": "Mariana.sublime-color-scheme",
        "themed_title_bar": true,
        "update_check": false
      }
    '';
  };
}
