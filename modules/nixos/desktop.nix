{ lib, settings, ... }:

{
  services.desktopManager.plasma6.enable = true;

  # Run games in a nested compositor inside Plasma, without a privileged
  # scheduling wrapper or a separate login session. HDR stays opt-in upstream.
  programs.gamescope = {
    enable = settings.features.gaming.gamescope;
    capSysNice = false;
  };

  # NAPS2 needs scanner drivers/udev rules as well as its GUI package.
  # This enables local access only; saned and discovery firewall ports stay off.
  hardware.sane.enable = settings.features.utilities.naps2;
  users.users.${settings.user.name}.extraGroups = lib.optionals settings.features.utilities.naps2 [
    "scanner"
    "lp"
  ];

  # Plasma enables GeoClue by default. This workstation uses the explicit IANA
  # zone from settings.nix, so automatic location, weather-location discovery,
  # travel-based timezone changes and location-based Night Color are disabled.
  services.geoclue2.enable = false;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Panther Lake/Xe3: load Xe early without force_probe or module blacklists.
  # Retain modern media/compute/VPL support, excluding the legacy i965 driver.
  hardware.intelgpu = {
    driver = "xe";
    vaapiDriver = "intel-media-driver";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.bluetooth = {
    enable = true;
    # Avoid passive Bluetooth advertising/scanning until the user requests it.
    powerOnBoot = false;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
  };
}
