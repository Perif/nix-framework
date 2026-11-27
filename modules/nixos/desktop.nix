{
  lib,
  pkgs,
  settings,
  ...
}:

{
  services.desktopManager.plasma6.enable = true;

  # CUPS provides the print backend used by KDE applications and dialogs.
  # Avahi discovers driverless IPP/AirPrint printers on trusted local networks.
  # Plasma automatically includes Print Manager when CUPS is enabled.
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  # Run games in a nested compositor inside Plasma, without a privileged
  # scheduling wrapper or a separate login session. HDR stays opt-in upstream.
  programs.gamescope = {
    enable = settings.features.gaming.gamescope;
    capSysNice = false;
  };

  # Steam needs the system-level launcher and its 32-bit runtime support;
  # keep network-facing helpers disabled unless explicitly needed.
  programs.steam = {
    enable = settings.features.gaming.steam;
    remotePlay.openFirewall = false;
    dedicatedServer.openFirewall = false;
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

  # The CalDigit TS4's primary USB 3 hub is a stable dock-level device.  Tag
  # only its add event, not any peripherals connected through the dock, then
  # ask systemd to power Bluetooth on after BlueZ is available.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2188", ATTR{idProduct}=="5500", TAG+="systemd", ENV{SYSTEMD_WANTS}+="bluetooth-on-caldigit-ts4.service"
  '';

  systemd.services.bluetooth-on-caldigit-ts4 = {
    description = "Power on Bluetooth when the CalDigit TS4 is connected";
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bluez}/bin/bluetoothctl power on";
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland;xcb";

    # xpadneo exposes the Elite Series 2 correctly through evdev, but Steam's
    # Xbox HIDAPI backend detects the compatibility PID and receives no input.
    # Keep Steam on SDL's evdev backend for this Bluetooth controller.
    SDL_JOYSTICK_HIDAPI_XBOX = "0";
  };
}
