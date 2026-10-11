{ lib, settings, ... }:

{
  imports = [
    ../modules/firefox.nix
    ../modules/privacy.nix
    ../modules/plasma-security.nix
    ../modules/power.nix
    ../modules/touchpad.nix
    ../modules/ghostty.nix
    ../modules/vim.nix
    ../modules/git.nix
    ../modules/zsh.nix
    ../modules/workstation-apps.nix
    ../modules/personal-apps.nix
    ../modules/strawberry.nix
    ../modules/music-tools.nix
    ../modules/dc-elite.nix
    ../modules/display-color.nix
    ../modules/easyeffects.nix
  ]
  ++ lib.optional settings.features.qbz ../modules/qbz.nix
  ++ lib.optional settings.features.extraBrowsers ../modules/browsers.nix
  ++ lib.optionals settings.features.extraEditors [
    ../modules/sublime.nix
    ../modules/vscodium.nix
  ]
  ++ lib.optional settings.features.localAI ../modules/ai.nix
  ++ lib.optional settings.features.rea ../modules/rea.nix
  ++ lib.optional (
    settings.features.devCore
    || builtins.any (enabled: enabled) (builtins.attrValues settings.features.languageTools)
  ) ../modules/dev-tools.nix;

  home.username = settings.user.name;
  home.homeDirectory = "/home/${settings.user.name}";

  # Keep this at the Home Manager state version used at initial install.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  xdg.enable = true;
}
