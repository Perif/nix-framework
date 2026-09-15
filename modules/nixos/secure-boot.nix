{
  lib,
  pkgs,
  settings,
  ...
}:

let
  enabled = settings.features.secureBoot;
in
{
  # Keep the key-management and verification tool available before the signed
  # boot path is enabled. Secret keys remain local under /var/lib/sbctl.
  environment.systemPackages = [ pkgs.sbctl ];

  # Lanzaboote replaces the regular systemd-boot installation logic. The
  # initial install deliberately uses ordinary systemd-boot; after local keys
  # are generated, the single settings flag switches ownership safely.
  boot.loader.systemd-boot.enable = lib.mkForce (!enabled);
  # Bound EFI usage independently of the age-based Nix garbage collector.
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.lanzaboote = {
    enable = enabled;
    configurationLimit = 3;
    pkiBundle = "/var/lib/sbctl";
  };
}
