{ pkgs }:
let
  thermald = pkgs.callPackage ./thermald.nix { };
in
pkgs.writeShellApplication {
  name = "framework-power-report";
  runtimeInputs = [
    pkgs.python3
    pkgs.power-profiles-daemon
    pkgs.systemd
    pkgs.lm_sensors
    pkgs.usbutils
    pkgs.intel-gpu-tools
  ];
  text = ''
    export PATH="${thermald}/sbin:$PATH"
    exec python3 ${../scripts/power-report.py} "$@"
  '';
}
