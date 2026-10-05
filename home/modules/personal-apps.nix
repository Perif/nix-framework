{
  lib,
  pkgs,
  settings,
  ...
}:

let
  office = settings.features.office;
in
{
  home.packages =
    lib.optionals office.libreOffice [ pkgs.libreoffice-qt ]
    ++ lib.optionals office.thunderbird [ pkgs.thunderbird ]
    ++ lib.optionals office.kdeConnect [ pkgs.kdePackages.kdeconnect-kde ]
    ++ lib.optionals office.syncthing [ pkgs.syncthing ];

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
