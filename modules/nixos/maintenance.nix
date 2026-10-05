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
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./scripts/ac-maintenance.sh;
  };
in
{
  # Keep upstream calendar timers, scrub cancellation, priorities and commands.
  # ExecCondition records a pending job when a calendar timer fires on battery;
  # a small retry timer catches it on AC without running every job at each plug-in.
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
          description = "Retry pending laptop maintenance while on AC";
          unitConfig.ConditionACPower = true;
          serviceConfig.Type = "oneshot";
          script = lib.concatMapStringsSep "\n" (unit: ''
            if test -e ${stateDir}/${unit}.pending; then
              ${pkgs.systemd}/bin/systemctl --no-block start ${unit}.service
            fi
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
