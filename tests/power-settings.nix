{ pkgs }:
let
  lib = pkgs.lib // {
    hm.dag.entryAfter = _: script: script;
  };
  base = import ../settings.nix;
  selection =
    mode: refresh:
    base
    // {
      power = base.power // {
        sleepMode = mode;
        hibernateDelayMinutes = 25;
        chargeLimit = null;
      };
      display = base.display // {
        refreshRate = base.display.refreshRate // {
          enable = refresh;
        };
      };
    };
  system =
    settings:
    import ../modules/nixos/power.nix {
      inherit pkgs lib settings;
      config = { };
    };
  home =
    settings:
    import ../home/modules/power.nix {
      inherit pkgs lib settings;
      config.xdg.configHome = "${builtins.placeholder "out"}/config";
    };
  cases = [
    {
      mode = "suspend";
      action = "1";
      sleep = "1";
    }
    {
      mode = "hibernate";
      action = "2";
      sleep = "1";
    }
    {
      mode = "suspend-then-hibernate";
      action = "1";
      sleep = "3";
    }
  ];
  valid = settings: builtins.all (check: check.assertion) (system settings).assertions;
  withPower = power: base // { power = base.power // power // { chargeLimit = null; }; };
in
assert builtins.all (
  case:
  let
    cfg = system (selection case.mode true);
  in
  valid (selection case.mode true)
  && cfg.services.logind.settings.Login.HandleLidSwitch == case.mode
  && cfg.services.logind.settings.Login.HandlePowerKey == case.mode
  && cfg.systemd.sleep.settings.Sleep.HibernateDelaySec == "25min"
  && cfg.systemd.sleep.settings.Sleep.HibernateOnACPower == "yes"
) cases;
assert
  !valid (withPower {
    sleepMode = "deep";
  });
assert
  !valid (withPower {
    hibernateDelayMinutes = 0;
  });
assert
  !valid (withPower {
    hibernateDelayMinutes = "60";
  });
assert
  !valid (withPower {
    hibernateOnAC = "no";
  });
assert
  (system (withPower {
    hibernateOnAC = false;
  })).systemd.sleep.settings.Sleep.HibernateOnACPower == "no";
pkgs.runCommand "power-settings-tests" { nativeBuildInputs = [ pkgs.kdePackages.kconfig ]; } ''
  export QT_QPA_PLATFORM=offscreen
  mkdir -p "$out/config"
  run() { "$@"; }
  cat > "$out/config/powerdevilrc" <<'EOF'
  [AC][Display]
  DisplayBrightness=42
  [AC][SuspendAndShutdown]
  AutoSuspendAction=0
  AutoSuspendIdleTimeoutSec=789
  [AC][RunScript]
  ProfileLoadCommand=existing-load
  ProfileUnloadCommand=existing-unload
  EOF
  ${lib.concatMapStringsSep "\n" (case: ''
    ${(home (selection case.mode true)).home.activation.powerSourceProfiles}
    for source in AC Battery LowBattery; do
      test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group "$source" --group SuspendAndShutdown --key LidAction)" = ${case.action}
      test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group "$source" --group SuspendAndShutdown --key PowerButtonAction)" = ${case.action}
      test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group "$source" --group SuspendAndShutdown --key SleepMode)" = ${case.sleep}
      test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group "$source" --group RunScript --key ProfileLoadCommand)" = '/run/current-system/sw/bin/systemctl --user --no-block restart framework-display-sdr.service'
    done
  '') cases}
  kwriteconfig6 --file "$out/config/powerdevilrc" --group Battery --group RunScript --key ProfileLoadCommand custom-command
  ${(home (selection "suspend-then-hibernate" false)).home.activation.powerSourceProfiles}
  test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group AC --group RunScript --key ProfileLoadCommand)" = existing-load
  test -z "$(kreadconfig6 --file "$out/config/powerdevilrc" --group LowBattery --group RunScript --key ProfileLoadCommand)"
  test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group Battery --group RunScript --key ProfileLoadCommand)" = custom-command
  test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group AC --group RunScript --key ProfileUnloadCommand)" = existing-unload
  test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group AC --group Display --key DisplayBrightness)" = 42
  test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group AC --group SuspendAndShutdown --key AutoSuspendAction)" = 0
  test "$(kreadconfig6 --file "$out/config/powerdevilrc" --group AC --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec)" = 789
''
