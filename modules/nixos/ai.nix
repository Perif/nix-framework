{
  lib,
  pkgs,
  settings,
  ...
}:

{
  assertions = [
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

  # Ollama is a system service because multiple local clients/agents can
  # use its loopback API. llama.cpp itself is installed in Home Manager.
  services.ollama = {
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
  systemd.services.ollama.wantedBy = lib.mkForce [ ];
  systemd.services.ollama.unitConfig.RequiresMountsFor = [ "/var/lib/private/ollama" ];
  # Preserve DynamicUser's private ancestor even before the first service run.
  systemd.tmpfiles.rules = [ "d /var/lib/private 0700 root root -" ];

  nixpkgs.config.allowUnfreePackages = lib.optional settings.ai.webui.enable "open-webui";
  services.open-webui = lib.mkIf settings.ai.webui.enable {
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
      ENABLE_SIGNUP = if settings.ai.webui.allowSignup then "True" else "False";
      OFFLINE_MODE = "True";
      HF_HUB_OFFLINE = "1";
      ENABLE_VERSION_UPDATE_CHECK = "False";
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
    };
  };
  systemd.services.open-webui = lib.mkIf settings.ai.webui.enable {
    wantedBy = lib.mkForce [ ];
    requires = [ "ollama.service" ];
    after = [ "ollama.service" ];
    # Persist a cryptographic session key in the private service state, not Nix.
    preStart = lib.mkBefore ''
      if [ ! -s .webui_secret_key ]; then
        umask 077
        ${pkgs.openssl}/bin/openssl rand -base64 32 > .webui_secret_key
      fi
    '';
  };
}
