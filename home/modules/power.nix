{
  config,
  lib,
  pkgs,
  settings,
  ...
}:

let
  profiles = {
    AC = settings.power.acProfile;
    Battery = settings.power.batteryProfile;
    LowBattery = settings.power.lowBatteryProfile;
  };
in
{
  assertions = [
    {
      assertion = builtins.all (
        profile:
        builtins.elem profile [
          "performance"
          "balanced"
          "power-saver"
        ]
      ) (builtins.attrValues profiles);
      message = "Power profiles must be performance, balanced or power-saver.";
    }
  ];

  # Own power profile, sleep mode and lid/power-button actions; preserve
  # brightness and idle timeouts. Plasma 6.6 reads powerdevilrc, not the old
  # powermanagementprofilesrc. Log out/in after the first activation to reload.
  home.activation.powerSourceProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (source: profile: ''
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group Performance \
          --key PowerProfile ${lib.escapeShellArg profile}
        # Plasma takes a logind inhibitor and owns these events in the session.
        # PowerButtonAction.Sleep=1; SleepMode.SuspendThenHibernate=3 (Plasma 6.6).
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group SuspendAndShutdown \
          --key SleepMode 3
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group SuspendAndShutdown \
          --key LidAction 1
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group SuspendAndShutdown \
          --key PowerButtonAction 1
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group SuspendAndShutdown \
          --key InhibitLidActionWhenExternalMonitorPresent true
      '') profiles
    )
  );
}
