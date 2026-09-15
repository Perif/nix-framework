{ pkgs, ... }:

{
  # System-wide policy is kept in modules/nixos/browsers.nix. Home Manager
  # owns only the browser packages so their user profiles stay independent.
  # Use the Nixpkgs ungoogled build for the Chromium compatibility profile;
  # Brave remains the Chromium-family profile with Google-backed Safe Browsing
  # and managed Chrome Web Store extension updates.
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;
  };

  programs.brave = {
    enable = true;
    package = pkgs.brave;
  };
}
