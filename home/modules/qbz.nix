{ pkgs, qbz, ... }:

{
  # Retain the last validated upstream flake; current upstream removed it.
  # See docs/UPDATES.md before changing this input.
  home.packages = [
    qbz.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
