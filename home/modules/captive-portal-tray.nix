{ pkgs, ... }:

let
  captivePortalTray = pkgs.writeShellApplication {
    name = "captive-portal-tray";
    runtimeInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyqt6 ])) ];
    text = ''
      exec python3 ${./captive-portal-tray.py}
    '';
  };
in
{
  # A StatusNotifier item appears in Plasma's existing system tray. Its menu
  # starts/stops the system service; the session Polkit agent requests the
  # configured fprintd authentication rather than exposing a root shell.
  systemd.user.services.captive-portal-tray = {
    Unit = {
      Description = "Captive portal mode tray control";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${captivePortalTray}/bin/captive-portal-tray";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
