{ settings, ... }:

{
  imports = [
    ./disk.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/dns-filter.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/controllers.nix
    ../../modules/nixos/power.nix
    ../../modules/nixos/maintenance.nix
    ../../modules/nixos/performance.nix
    ../../modules/nixos/security.nix
    ../../modules/nixos/secure-boot.nix
    ../../modules/nixos/storage.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/ai.nix
    ../../modules/nixos/browsers.nix
    ../../modules/nixos/containers.nix
  ];

  networking.hostName = settings.hostname;

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
