{ ... }:

{
  services.desktopManager.plasma6.enable = true;

  # Plasma enables GeoClue by default. This workstation uses the explicit IANA
  # zone from settings.nix, so automatic location, weather-location discovery,
  # travel-based timezone changes and location-based Night Color are disabled.
  services.geoclue2.enable = false;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
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
