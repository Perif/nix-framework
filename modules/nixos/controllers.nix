{ pkgs, ... }:

{
  # Elite Series 2 over Bluetooth. Use the pinned kernel-matched Nix package,
  # not an out-of-band DKMS install. Desktop policy keeps Bluetooth off at boot.
  hardware.xpadneo.enable = true;

  # xpad handles USB-C; uhid is required by BlueZ for newer BLE firmware.
  boot.kernelModules = [ "xpad" "uhid" ];

  # Run only against the controller event device when diagnosing input.
  # Do not grant the user blanket membership of the input group.
  environment.systemPackages = [ pkgs.evtest ];
}
