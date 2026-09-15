{ pkgs, settings, ... }:

let
  diskAlert = pkgs.writeShellApplication {
    name = "disk-health-record-alert";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      # Only root can create/update this marker. No device-controlled message
      # is forwarded to the desktop, and alerts survive logout/reboot.
      touch /var/lib/disk-health/alert
      printf '%s\n' "SMART disk-health warning: inspect journalctl -u smartd" | wall || true
    '';
  };
  monitorOptions = "-a -m <nomailer> -M exec ${diskAlert}/bin/disk-health-record-alert";
in
{
  # Monitor every locally discovered SMART-capable drive, including NVMe.
  # Health failures go to the journal, terminals and the Plasma user; routine
  # checks do not generate notifications or require a network/mail account.
  services.smartd = {
    enable = true;
    autodetect = true;
    # Our handler retains terminal warnings and records a persistent alert.
    defaults.monitored = monitorOptions;
    defaults.autodetected = monitorOptions;
  };

  systemd.tmpfiles.rules = [ "d /var/lib/disk-health 0755 root root -" ];
  systemd.user.services.disk-health-alert = {
    description = "Display a pending SMART disk-health warning";
    after = [ "graphical-session.target" ];
    requisite = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    unitConfig = {
      ConditionUser = settings.user.name;
      ConditionPathExists = "/var/lib/disk-health/alert";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.libnotify}/bin/notify-send --urgency=critical --app-name=Disk-health 'Disk health needs attention' 'Inspect sudo journalctl -u smartd. This warning repeats until acknowledged; see docs/INSTALL.md.'";
      NoNewPrivileges = true;
    };
  };
  systemd.user.paths.disk-health-alert = {
    description = "Watch the root-owned SMART warning marker";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    pathConfig.PathChanged = "/var/lib/disk-health/alert";
  };
  systemd.user.timers.disk-health-alert = {
    description = "Remind the desktop about unacknowledged disk warnings";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    timerConfig = {
      OnActiveSec = "1min";
      OnUnitActiveSec = "1h";
    };
  };

  # Scrub the physical Btrfs filesystem once; the other declared mount points
  # are subvolumes on the same device.
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
    interval = "monthly";
  };

  # /.snapshots is a dedicated Btrfs subvolume in the Disko layout. Snapper
  # snapshots only root; /home, /nix, /var/log and Ollama state remain separate
  # and are intentionally excluded. Snapshots are rollback aids, not backups.
  services.snapper = {
    snapshotRootOnBoot = true;
    persistentTimer = true;
    cleanupInterval = "1d";

    configs.root = {
      SUBVOLUME = "/";
      FSTYPE = "btrfs";

      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 6;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 6;
      TIMELINE_LIMIT_QUARTERLY = 0;
      TIMELINE_LIMIT_YEARLY = 0;

      NUMBER_CLEANUP = true;
      NUMBER_MIN_AGE = 1800;
      NUMBER_LIMIT = 10;
      NUMBER_LIMIT_IMPORTANT = 5;
      EMPTY_PRE_POST_CLEANUP = true;
    };
  };
}
