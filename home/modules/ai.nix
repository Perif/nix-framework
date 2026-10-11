{
  config,
  lib,
  pkgs,
  osConfig,
  settings,
  ...
}:

let
  aiEnabled = settings.features.localAI;
  ollayaEnabled = aiEnabled && settings.ai.ollaya.enable;
  webuiEnabled = aiEnabled && settings.ai.webui.enable;
  ollaya = pkgs.callPackage ../../pkgs/ollaya.nix { };
  ollayaEnvironment = import ./ollaya-environment.nix {
    inherit (config.home) homeDirectory;
  };
in

{
  home.packages =
    lib.optionals aiEnabled [
      # llama.cpp is the lower-level local runtime for explicit GGUF,
      # context, quantization and backend control. nixpkgs' plain llama-cpp
      # is CPU-only; the -vulkan variant matches the Ollama service and is
      # served from the binary cache.
      pkgs.llama-cpp-vulkan
      pkgs.intel-gpu-tools

      # The Ollama daemon is a NixOS service. Reuse its exact package for the
      # user CLI so the closure does not also carry a second, CPU-only
      # ollama build.
      osConfig.services.ollama.package
    ]
    ++ lib.optional ollayaEnabled ollaya;

  # The CLI can auto-start its own daemon; keep those defaults consistent with
  # the managed user service too. Prefer ollaya-on before making requests.
  home.sessionVariables = lib.mkIf ollayaEnabled ollayaEnvironment;

  systemd.user.services.ollaya = lib.mkIf ollayaEnabled {
    Unit.Description = "Ollaya local decision models (Intel CPU)";
    # No Install.WantedBy: installed but not started at login.
    Service = {
      ExecStart = "${ollaya}/bin/ollaya serve";
      Environment = lib.mapAttrsToList (name: value: "${name}=${value}") ollayaEnvironment;
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStopSec = 30;
      UMask = "0077";
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
    };
  };

  programs.zsh.shellAliases =
    lib.optionalAttrs aiEnabled {
      ollama-on = "sudo systemctl start ollama.service";
      ollama-off = "sudo systemctl stop ollama.service";
      ollama-status = "systemctl --no-pager --full status ollama.service";
    }
    // lib.optionalAttrs ollayaEnabled {
      ollaya-on = "systemctl --user start ollaya.service";
      ollaya-off = "systemctl --user stop ollaya.service";
      ollaya-status = "systemctl --user status ollaya.service";
    }
    // lib.optionalAttrs webuiEnabled {
      webui-bootstrap = "sudo /run/current-system/sw/bin/webui-bootstrap";
      webui-on = "sudo systemctl start open-webui.service";
      webui-off = "sudo systemctl stop open-webui.service";
      webui-status = "systemctl status open-webui.service";
    };
}
