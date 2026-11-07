{ pkgs, ... }:

{
  # System-wide policy is kept in modules/nixos/browsers.nix. Home Manager
  # owns only the browser packages so their user profiles stay independent.
  # Use the Nixpkgs ungoogled build for the Chromium compatibility profile.
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;
  };
}
