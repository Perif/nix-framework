{
  config,
  lib,
  pkgs,
  settings,
  utils,
  ...
}:

let
  units =
    lib.optional config.nix.gc.automatic "nix-gc"
    ++ lib.optionals config.services.btrfs.autoScrub.enable (
      map (fs: "btrfs-scrub-${utils.escapeSystemdPath fs}") config.services.btrfs.autoScrub.fileSystems
    );
  stateDir = "/var/lib/ac-maintenance";
  guard = pkgs.writeShellApplication {
    name = "ac-maintenance";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
    ];
    text = builtins.readFile ./scripts/ac-maintenance.sh;
  };
in
{
  # Keep upstream calendar timers, scrub cancellation, priorities and commands.
  # ExecCondition records why a job is pending when a calendar timer fires; a
  # small retry timer relaunches battery-deferred or interrupted work on AC,
  # while a job that ran and failed waits for its next calendar run.
  config = lib.mkIf settings.power.maintenanceOnAC {
    systemd.services =
      lib.genAttrs units (unit: {
        serviceConfig = {
          StateDirectory = "ac-maintenance";
          StateDirectoryMode = "0700";
          ExecCondition = lib.mkBefore [
            "${guard}/bin/ac-maintenance check ${stateDir}/${unit}.pending ${pkgs.systemd}/bin/systemd-ac-power"
          ];
          ExecStopPost = lib.mkAfter [
            "${guard}/bin/ac-maintenance finish ${stateDir}/${unit}.pending"
          ];
        };
      })
      // {
        ac-maintenance-retry = {
          description = "Retry deferred or interrupted laptop maintenance while on AC";
          unitConfig.ConditionACPower = true;
          serviceConfig.Type = "oneshot";
          script = lib.concatMapStringsSep "\n" (unit: ''
            ${guard}/bin/ac-maintenance retry ${stateDir}/${unit}.pending ${unit}
          '') units;
        };
      };
    systemd.timers.ac-maintenance-retry = {
      description = "Check for deferred AC maintenance";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
        AccuracySec = "1min";
      };
    };
  };
}
