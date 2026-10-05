{ lib, settings, ... }:

{
  imports = [
    ../modules/firefox.nix
    ../modules/browsers.nix
    ../modules/privacy.nix
    ../modules/plasma-security.nix
    ../modules/power.nix
    ../modules/ghostty.nix
    ../modules/vim.nix
    ../modules/sublime.nix
    ../modules/git.nix
    ../modules/zsh.nix
    ../modules/dev-tools.nix
    ../modules/ai.nix
    ../modules/vscodium.nix
    ../modules/strawberry.nix
    ../modules/dc-elite.nix
    ../modules/display-color.nix
    ../modules/easyeffects.nix
  ]
  ++ lib.optional settings.features.qbz ../modules/qbz.nix;

  home.username = settings.user.name;
  home.homeDirectory = "/home/${settings.user.name}";

  # Keep this at the Home Manager state version used at initial install.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  xdg.enable = true;
}
