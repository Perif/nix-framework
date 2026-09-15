{ lib, pkgs, ... }:

{
  # Ollama is a system service because multiple local clients/agents can
  # use its loopback API. llama.cpp itself is installed in Home Manager.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
  };

  # Keep the hardened service definition and persistent model store, but do not
  # start the daemon at boot. The configured user starts and stops it explicitly
  # with the documented systemctl commands or Zsh aliases when local inference
  # is needed.
  systemd.services.ollama.wantedBy = lib.mkForce [ ];
  systemd.services.ollama.unitConfig.RequiresMountsFor = [ "/var/lib/private/ollama" ];
  # Preserve DynamicUser's private ancestor even before the first service run.
  systemd.tmpfiles.rules = [ "d /var/lib/private 0700 root root -" ];
}
