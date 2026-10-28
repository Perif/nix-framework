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
    ++ lib.optionals office.kdeConnect [ pkgs.kdePackages.kdeconnect-kde ]
    ++ lib.optionals office.syncthing [ pkgs.syncthing ]
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
  xdg.configFile = lib.optionalAttrs office.kdeConnect {
    "autostart/org.kde.kdeconnect.daemon.desktop".text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };
}
