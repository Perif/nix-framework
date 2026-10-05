{
  config,
  lib,
  pkgs,
  osConfig,
  settings,
  ...
}:

let
  ollaya = pkgs.callPackage ../../pkgs/ollaya.nix { };
  ollayaEnvironment = {
    OLLAYA_HOST = "127.0.0.1:11435";
    OLLAYA_DEVICE = "cpu";
    OLLAYA_MODELS = "${config.home.homeDirectory}/.ollaya/models";
    OLLAYA_MAX_LOADED_MODELS = "1";
    OLLAYA_MAX_QUEUE = "16";
    OLLAYA_KEEP_ALIVE = "5m";
  };
in

{
  home.packages = [
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
  ++ lib.optional settings.ai.ollaya.enable ollaya;

  # The CLI can auto-start its own daemon; keep those defaults consistent with
  # the managed user service too. Prefer ollaya-on before making requests.
  home.sessionVariables = lib.mkIf settings.ai.ollaya.enable ollayaEnvironment;

  systemd.user.services.ollaya = lib.mkIf settings.ai.ollaya.enable {
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

  programs.zsh.shellAliases = lib.mkIf settings.ai.ollaya.enable {
    ollaya-on = "systemctl --user start ollaya.service";
    ollaya-off = "systemctl --user stop ollaya.service";
    ollaya-status = "systemctl --user status ollaya.service";
  };
}
