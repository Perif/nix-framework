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
  # Plasma uses a distinct action for direct hibernation, not SleepMode=2
  # (which means hybrid sleep). Keep console and desktop lid/key behavior aligned.
  sleepMode = if settings.power.sleepMode == "suspend-then-hibernate" then "3" else "1";
  sleepAction = if settings.power.sleepMode == "hibernate" then "2" else "1";
  # Restart instead of start: a power transition during an active oneshot must
  # schedule a fresh UPower read, rather than coalescing into the earlier start.
  refreshCommand = "/run/current-system/sw/bin/systemctl --user --no-block restart framework-display-sdr.service";
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
        # Plasma 6.6: Sleep=1, Hibernate=2; SuspendToRam=1, SuspendThenHibernate=3.
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group SuspendAndShutdown \
          --key SleepMode ${sleepMode}
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group SuspendAndShutdown \
          --key LidAction ${sleepAction}
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group SuspendAndShutdown \
          --key PowerButtonAction ${sleepAction}
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
          --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
          --group ${lib.escapeShellArg source} --group SuspendAndShutdown \
          --key InhibitLidActionWhenExternalMonitorPresent true
        ${
          if settings.display.refreshRate.enable then
            ''
              previousCommand="$(${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
                --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
                --group ${lib.escapeShellArg source} --group RunScript --key ProfileLoadCommand)"
              if [[ "$previousCommand" != ${lib.escapeShellArg refreshCommand} ]]; then
                run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
                  --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
                  --group FrameworkRefreshPolicy --group ${lib.escapeShellArg source} \
                  --key PreviousProfileLoadCommand "$previousCommand"
              fi
              run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
                --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
                --group ${lib.escapeShellArg source} --group RunScript \
                --key ProfileLoadCommand ${lib.escapeShellArg refreshCommand}
            ''
          else
            ''
              # Restore only our hook on opt-out; keep commands subsequently set in the GUI.
              if [[ "$(${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
                  --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
                  --group ${lib.escapeShellArg source} --group RunScript \
                  --key ProfileLoadCommand)" == ${lib.escapeShellArg refreshCommand} ]]; then
                previousCommand="$(${pkgs.kdePackages.kconfig}/bin/kreadconfig6 \
                  --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
                  --group FrameworkRefreshPolicy --group ${lib.escapeShellArg source} \
                  --key PreviousProfileLoadCommand)"
                if [[ -n "$previousCommand" ]]; then
                  run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
                    --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
                    --group ${lib.escapeShellArg source} --group RunScript \
                    --key ProfileLoadCommand "$previousCommand"
                else
                  run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
                    --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
                    --group ${lib.escapeShellArg source} --group RunScript \
                    --key ProfileLoadCommand --delete
                fi
              fi
              run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
                --file ${lib.escapeShellArg "${config.xdg.configHome}/powerdevilrc"} \
                --group FrameworkRefreshPolicy --group ${lib.escapeShellArg source} \
                --key PreviousProfileLoadCommand --delete
            ''
        }
      '') profiles
    )
  );
}
