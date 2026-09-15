{ pkgs, ... }:

{
  programs.vscodium = {
    enable = true;

    # Extensions are reviewed and updated with the flake instead of being
    # installed imperatively from a marketplace at runtime.
    mutableExtensionsDir = false;

    argvSettings = {
      enable-crash-reporter = false;
    };

    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;

      extensions = with pkgs.vscode-extensions; [
        # One reviewed agent extension is enough: Continue supports both local
        # providers below without adding a second extension with overlapping
        # repository and command-execution privileges.
        continue.continue

        jnoortheen.nix-ide

        ms-python.python
        ms-python.debugpy
        detachhead.basedpyright
        charliermarsh.ruff

        golang.go

        rust-lang.rust-analyzer
        vadimcn.vscode-lldb

        redhat.vscode-yaml
        tamasfe.even-better-toml
        editorconfig.editorconfig
      ];

      userSettings = {
        # VSCodium already removes Microsoft's product telemetry endpoints;
        # keep the editor and installed extensions opted out as well.
        "telemetry.telemetryLevel" = "off";
        "telemetry.enableTelemetry" = false;
        "telemetry.enableCrashReporter" = false;
        "workbench.enableExperiments" = false;
        "workbench.settings.enableNaturalLanguageSearch" = false;
        "extensions.ignoreRecommendations" = true;
        "extensions.showRecommendationsOnlyOnDemand" = true;

        # Opening an unknown repository remains an explicit trust decision.
        "security.workspace.trust.enabled" = true;
        "security.workspace.trust.startupPrompt" = "always";
        "security.workspace.trust.untrustedFiles" = "newWindow";
        "security.workspace.trust.emptyWindow" = false;
        "task.allowAutomaticTasks" = "off";

        # Make invisible and bidirectional Unicode visible during source
        # review. Non-ASCII text itself remains allowed.
        "editor.unicodeHighlight.ambiguousCharacters" = true;
        "editor.unicodeHighlight.invisibleCharacters" = true;
        "editor.unicodeHighlight.includeComments" = true;
        "editor.unicodeHighlight.includeStrings" = true;

        # Predictable file hygiene and a responsive editing baseline.
        "files.insertFinalNewline" = true;
        "files.trimFinalNewlines" = true;
        "files.trimTrailingWhitespace" = true;
        "files.autoSave" = "off";
        "editor.detectIndentation" = true;
        "editor.insertSpaces" = true;
        "editor.tabSize" = 4;
        "editor.rulers" = [
          88
          100
        ];
        "editor.minimap.enabled" = false;
        "editor.stickyScroll.enabled" = true;
        "editor.largeFileOptimizations" = true;
        "editor.renderWhitespace" = "selection";
        "editor.guides.bracketPairs" = "active";

        # Do not recursively watch generated dependency/build trees. Git still
        # sees its metadata; only high-churn object storage is excluded.
        "files.watcherExclude" = {
          "**/.git/objects/**" = true;
          "**/.git/subtree-cache/**" = true;
          "**/.direnv/**" = true;
          "**/.venv/**" = true;
          "**/node_modules/**" = true;
          "**/result/**" = true;
          "**/target/**" = true;
        };
        "search.exclude" = {
          "**/.direnv" = true;
          "**/.venv" = true;
          "**/node_modules" = true;
          "**/result" = true;
          "**/target" = true;
        };

        # Avoid surprise network and CPU activity in a lightweight local-AI
        # profile. Chat, edit and agent requests remain available on demand.
        "git.autofetch" = false;
        "git.confirmSync" = true;
        "git.openRepositoryInParentFolders" = "never";
        "continue.telemetryEnabled" = false;
        "continue.enableTabAutocomplete" = false;
        "continue.enableNextEdit" = false;
        "continue.pauseTabAutocompleteOnBattery" = true;
        "continue.pauseCodebaseIndexOnStart" = true;
        "continue.remoteConfigServerUrl" = "";

        "redhat.telemetry.enabled" = false;
        "ruff.nativeServer" = "on";

        "basedpyright.analysis.diagnosticMode" = "openFilesOnly";
        "basedpyright.analysis.typeCheckingMode" = "basic";
        "basedpyright.disableOrganizeImports" = true;

        "go.useLanguageServer" = true;
        "go.toolsManagement.autoUpdate" = false;
        "gopls" = {
          gofumpt = true;
          staticcheck = true;
          usePlaceholders = true;
        };

        "rust-analyzer.check.command" = "clippy";
        "rust-analyzer.cargo.buildScripts.enable" = true;
        "rust-analyzer.procMacro.enable" = true;

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.serverSettings" = {
          nixd.formatting.command = [ "nixfmt" ];
        };

        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.formatOnSave" = true;
        };
        "[python]" = {
          "editor.defaultFormatter" = "charliermarsh.ruff";
          "editor.formatOnSave" = true;
          "editor.codeActionsOnSave" = {
            "source.fixAll.ruff" = "explicit";
            "source.organizeImports.ruff" = "explicit";
          };
        };
        "[go]" = {
          "editor.defaultFormatter" = "golang.go";
          "editor.formatOnSave" = true;
        };
        "[rust]" = {
          "editor.defaultFormatter" = "rust-lang.rust-analyzer";
          "editor.formatOnSave" = true;
        };
      };
    };
  };

  # Continue's editor switch is deprecated but still honored by the pinned
  # extension. Its shared config is the authoritative second opt-out.
  home.file.".continue/.continuerc.json".text = builtins.toJSON {
    allowAnonymousTelemetry = false;
  };

  # Both endpoints are loopback-only. AUTODETECT exposes models deliberately
  # pulled into Ollama without hard-coding a large download into the rebuild.
  home.file.".continue/config.yaml".text = ''
    name: Local-only development
    version: 1.0.0
    schema: v1

    models:
      - name: Ollama local models
        provider: ollama
        model: AUTODETECT
        apiBase: http://127.0.0.1:11434
        roles:
          - chat
          - edit
          - apply
        defaultCompletionOptions:
          contextLength: 8192
          maxTokens: 2048
        requestOptions:
          noProxy:
            - 127.0.0.1
            - localhost

      - name: llama.cpp local server
        provider: llama.cpp
        model: local
        apiBase: http://127.0.0.1:8080
        roles:
          - chat
          - edit
          - apply
        defaultCompletionOptions:
          contextLength: 8192
          maxTokens: 2048
        requestOptions:
          noProxy:
            - 127.0.0.1
            - localhost
  '';
}
