{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  # Only this disposable test image has a test-driver backdoor. This module is
  # never imported by the laptop configuration or the project template.
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/testing/test-instrumentation.nix")
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [ "nvme" ];
  boot.kernelParams = [ "console=ttyS0" ];
  networking.hostName = "installer-target";
  users.users.owner = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
  services.getty.autologinUser = lib.mkForce null;
  environment.systemPackages = [ (pkgs.python3.withPackages (p: [ p.pexpect ])) ];
  documentation.enable = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  system.stateVersion = "26.05";
}
