{
  lib,
  pkgs,
  settings,
  ...
}:

{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.nh = {
    enable = true;
    osFlake = "/etc/nixos";
    clean.enable = false; # Existing AC-aware Nix GC remains the sole owner.
  };

  programs.keepassxc = {
    enable = settings.features.keepassxc;
    # Leave GUI settings writable for database history and browser pairing.
    # The module installs native messaging manifests for the selected browsers.
  };
  programs.firefox.profiles.default.extensions.packages =
    lib.optional settings.features.keepassxc pkgs.nur.repos.rycee.firefox-addons.keepassxc-browser;

  programs.mpv = {
    enable = true;
    config = {
      hwdec = "auto-safe"; # Supported hardware decoding, software fallback.
      vo = "gpu-next";
      ao = "pipewire"; # Desktop output; preserve the separate direct-DAC path.
    };
  };

  home.packages = [
    pkgs.hyperfine
  ]
  ++ lib.optionals settings.features.wine [
    pkgs.wineWow64Packages.stable
    pkgs.winetricks
  ];
}
