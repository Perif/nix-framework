{ ... }:

{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    installVimSyntax = true;

    settings = {
      "font-family" = "JetBrainsMono Nerd Font";
      "font-size" = 11;

      "clipboard-paste-protection" = false;
      "clipboard-read" = "allow";
      "clipboard-write" = "allow";
      "title-report" = false;

      "background-opacity" = 1.0;
      "background-blur" = false;
      "unfocused-split-opacity" = 0.85;

      "theme" = "Ayu Mirage";

      # Both limits are allocated lazily and apply per terminal surface. Keep
      # enough text history for development without letting many splits retain
      # large buffers indefinitely. Preserve inline-image compatibility while
      # reducing Ghostty's 320 MB image limit to 64 MiB per screen buffer.
      "scrollback-limit" = 8388608;
      "image-storage-limit" = 67108864;

      "background" = "#1f2430";
      "foreground" = "#cbccc6";

      "selection-background" = "#33415e";
      "selection-foreground" = "#cbccc6";

      "cursor-color" = "#ffcc66";
      "cursor-text" = "#1f2430";

      "palette" = [
        "0=#191e2a"
        "1=#ed8274"
        "2=#a6cc70"
        "3=#fad07b"
        "4=#6dcbfa"
        "5=#cfbafa"
        "6=#90e1c6"
        "7=#c7c7c7"
        "8=#686868"
        "9=#f28779"
        "10=#bae67e"
        "11=#ffd580"
        "12=#73d0ff"
        "13=#d4bfff"
        "14=#95e6cb"
        "15=#ffffff"
      ];

      "window-decoration" = true;
      # Integrate tabs into the GTK titlebar rather than reserving a second
      # row for them. This trims the window chrome while retaining tabs.
      "gtk-titlebar-style" = "tabs";
      "window-padding-x" = 8;
      "window-padding-y" = 6;

      "copy-on-select" = false;
      "confirm-close-surface" = true;
    };
  };
}
