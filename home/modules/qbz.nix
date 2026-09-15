{ pkgs, qbz, ... }:

{
  # Use QBZ's upstream flake rather than nixpkgs so the installed package
  # follows the release published by the QBZ project. flake.lock pins the
  # exact revision for reproducibility.
  home.packages = [
    qbz.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
