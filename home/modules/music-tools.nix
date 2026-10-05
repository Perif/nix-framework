{ pkgs, ... }:

{
  home.packages = [
    (pkgs.callPackage ../../pkgs/qobuz-player.nix { })
    pkgs.picard
  ];

  # Launch qobuz-player interactively and select the DAC using list-devices;
  # do not start a background player that could acquire it before Strawberry.
  # Account login and Picard's library edits remain interactive operations.
}
