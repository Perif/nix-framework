{
  lib,
  pkgs,
  settings,
  ...
}:

let
  aiEnabled = settings.features.localAI;
  webuiEnabled = aiEnabled && settings.ai.webui.enable;
  webuiBootstrapBase = pkgs.callPackage ../../pkgs/webui-bootstrap.nix { };
  webuiBootstrap = pkgs.writeShellApplication {
    name = "webui-bootstrap";
    text = ''
      exec ${webuiBootstrapBase}/bin/webui-bootstrap --port ${toString settings.ai.webui.port} "$@"
    '';
  };
  webuiBootstrapEnvFile = "/run/open-webui-bootstrap.env";
  webuiBootstrapPermitFile = "/run/open-webui-bootstrap.start";
in

{
  assertions = lib.optionals aiEnabled [
    {
      assertion =
        builtins.all (n: builtins.isInt n && n > 0) [
          settings.ai.contextLength
          settings.ai.maxOutputTokens
          settings.ai.maxLoadedModels
          settings.ai.parallelRequests
        ]
        && settings.ai.maxOutputTokens < settings.ai.contextLength;
      message = "AI context, output and concurrency values must be positive integers; output must fit the context.";
    }
    {
      assertion = builtins.elem settings.ai.kvCacheType [
        "f16"
        "q8_0"
        "q4_0"
      ];
      message = "ai.kvCacheType must be f16, q8_0 or q4_0.";
    }
  ];

  environment.systemPackages = lib.optional webuiEnabled webuiBootstrap;

  # Ollama is a system service because multiple local clients/agents can
  # use its loopback API. llama.cpp itself is installed in Home Manager.
  services.ollama = lib.mkIf aiEnabled {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
    environmentVariables = {
      # Ollama 0.32.3 drops integrated Vulkan devices by default, even when
      # Vulkan discovery is enabled by the package wrapper.
      OLLAMA_IGPU_ENABLE = "1";
      OLLAMA_NO_CLOUD = "1";
      OLLAMA_CONTEXT_LENGTH = toString settings.ai.contextLength;
      OLLAMA_MAX_LOADED_MODELS = toString settings.ai.maxLoadedModels;
      OLLAMA_NUM_PARALLEL = toString settings.ai.parallelRequests;
      OLLAMA_KEEP_ALIVE = settings.ai.keepAlive;
      OLLAMA_KV_CACHE_TYPE = settings.ai.kvCacheType;
    };
  };

  # Keep the hardened service definition and persistent model store, but do not
  # start the daemon at boot. The configured user starts and stops it explicitly
  # with the documented systemctl commands or Zsh aliases when local inference
  # is needed.
  systemd.services.ollama = lib.mkIf aiEnabled {
    wantedBy = lib.mkForce [ ];
    unitConfig.RequiresMountsFor = [ "/var/lib/private/ollama" ];
  };
  # Preserve DynamicUser's private ancestor even before the first service run.
  systemd.tmpfiles.rules = lib.optional aiEnabled "d /var/lib/private 0700 root root -";

  nixpkgs.config.allowUnfreePackages = lib.optional webuiEnabled "open-webui";
  services.open-webui = lib.mkIf webuiEnabled {
    enable = true;
    host = "127.0.0.1";
    port = settings.ai.webui.port;
    openFirewall = false;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      ENABLE_OLLAMA_API = "True";
      ENABLE_OPENAI_API = "False";
      ENABLE_PERSISTENT_CONFIG = "False";
      WEBUI_AUTH = "True";
      # First-admin creation is handled by `sudo webui-bootstrap`, which feeds
      # WEBUI_ADMIN_EMAIL/PASSWORD to Open WebUI through a root-only /run file.
      # Signup stays closed before and after that one-shot bootstrap.
      ENABLE_SIGNUP = "False";
      OFFLINE_MODE = "True";
      HF_HUB_OFFLINE = "1";
      ENABLE_VERSION_UPDATE_CHECK = "False";
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
    };
  };
  systemd.services.open-webui = lib.mkIf webuiEnabled {
    wantedBy = lib.mkForce [ ];
    requires = [ "ollama.service" ];
    after = [ "ollama.service" ];
    path = [ webuiBootstrap ];
    serviceConfig = {
      EnvironmentFile = [ "-${webuiBootstrapEnvFile}" ];
      ExecCondition = "${webuiBootstrap}/bin/webui-bootstrap --check-start --permit-file ${webuiBootstrapPermitFile}";
    };
    # Persist a cryptographic session key in the private service state, not Nix.
    preStart = lib.mkBefore ''
      if [ ! -s .webui_secret_key ]; then
        umask 077
        ${pkgs.openssl}/bin/openssl rand -base64 32 > .webui_secret_key
      fi
    '';
  };
}
