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

  # The encrypted volume remains the boot-time authentication boundary. Once
  # it is unlocked, enter this single-user laptop's Plasma session directly.
  services.displayManager.autoLogin = {
    enable = true;
    user = settings.user.name;
  };

  # Keep this at the release used for the initial installation.
  system.stateVersion = "26.05";

  # Panther Lake graphics, Wi-Fi, and Bluetooth require firmware distributed
  # separately from the kernel. Keep this hardware-specific requirement here
  # so a portable host configuration does not silently omit those devices.
  hardware.enableRedistributableFirmware = true;
}
