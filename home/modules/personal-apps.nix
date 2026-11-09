{
  lib,
  pkgs,
  settings,
  ...
}:

let
  office = settings.features.office;
  utilities = settings.features.utilities;
in
{
  home.packages =
    lib.optionals settings.features.gaming.beyondAllReason [ pkgs.beyond-all-reason ]
    ++ lib.optionals office.libreOffice [ pkgs.libreoffice-qt ]
    ++ lib.optionals office.thunderbird [ pkgs.thunderbird ]
    ++ lib.optionals office.signal [ pkgs.signal-desktop ]
    ++ lib.optionals office.kdeConnect [ pkgs.kdePackages.kdeconnect-kde ]
    ++ lib.optionals office.syncthing [ pkgs.syncthing ]
    ++ lib.optionals office.dropbox [ pkgs.dropbox ]
    ++ lib.optionals utilities.filezilla [ pkgs.filezilla ]
    ++ lib.optionals utilities.filelight [ pkgs.kdePackages.filelight ]
    ++ lib.optionals utilities.bruno [ pkgs.bruno ]
    ++ lib.optionals utilities.rclone [ pkgs.rclone ]
    ++ lib.optionals utilities.aria2 [ pkgs.aria2 ]
    ++ lib.optionals utilities.pdfarranger [ pkgs.pdfarranger ]
    ++ lib.optionals utilities.qpwgraph [ pkgs.qpwgraph ]
    ++ lib.optionals utilities.dbeaver [ pkgs.dbeaver-bin ]
    ++ lib.optionals utilities.audacity [ pkgs.audacity ]
    ++ lib.optionals utilities.naps2 [ pkgs.naps2 ];

  # KDE Connect ships an XDG login autostart entry. Mask it for this user so
  # installing the optional client does not start its network daemon at login;
  # launching KDE Connect manually can still D-Bus-activate the daemon.
  xdg.configFile =
    lib.optionalAttrs office.kdeConnect {
      "autostart/org.kde.kdeconnect.daemon.desktop".text = ''
        [Desktop Entry]
        Hidden=true
      '';
    }
    // lib.optionalAttrs office.dropbox {
      # Plasma honors XDG autostart entries when the user session begins. Reuse
      # the packaged entry so its command and desktop metadata stay in sync with
      # the Dropbox package.
      "autostart/dropbox.desktop".source = "${pkgs.dropbox}/share/applications/dropbox.desktop";
    };

  # Nixpkgs' Dropbox wrapper provides a desktop entry but no matching icon.
  # Install one in the standard icon theme location so Plasma resolves
  # `Icon=dropbox` in that entry without depending on Dropbox's self-updater.
  xdg.dataFile = lib.optionalAttrs office.dropbox {
    "icons/hicolor/scalable/apps/dropbox.svg".source = ../../assets/icons/dropbox.svg;
  };
}
