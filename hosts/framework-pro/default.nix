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

  # Local machine identity; keep the stable flake output name `framework-pro`
  # separate so this can be renamed without changing build targets.
  networking.hostName = "difool";

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";
}
