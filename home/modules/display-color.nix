{
  config,
  lib,
  pkgs,
  settings,
  ...
}:

let
  cfg = settings.display;
  notebookcheck = ../../assets/color/framework-13-pro-MND508ZB1-1.icm;
  selected = if cfg.profile == "custom" then cfg.iccProfile else notebookcheck;
  validName = name: builtins.match "[A-Za-z0-9_-]+" name != null;
  policyEnabled = cfg.disableHdr || cfg.refreshRate.enable;
  validHz = value: builtins.isInt value && value >= 30 && value <= 240;
  sdrPolicy = pkgs.writeShellScript "framework-display-sdr" ''
    exec ${pkgs.python3}/bin/python3 ${./display-sdr.py} \
      --doctor ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor \
      ${lib.optionalString (!cfg.disableHdr) "--allow-hdr"} \
      ${lib.optionalString cfg.refreshRate.enable ''
        --busctl ${pkgs.systemd}/bin/busctl \
        --battery-hz ${toString cfg.refreshRate.batteryHz} \
        --ac-hz ${if cfg.refreshRate.acHz == null then "highest" else toString cfg.refreshRate.acHz}
      ''}
  '';
  sessionUnit = {
    After = [ "plasma-kwin_wayland.service" ];
    Requisite = [ "plasma-kwin_wayland.service" ];
    PartOf = [ "graphical-session.target" ];
    ConditionEnvironment = "WAYLAND_DISPLAY";
  };
in
{
  assertions = [
    {
      assertion =
        builtins.isBool cfg.refreshRate.enable
        && validHz cfg.refreshRate.batteryHz
        && (cfg.refreshRate.acHz == null || validHz cfg.refreshRate.acHz);
      message = "display.refreshRate needs a boolean enable, integer batteryHz (30..240), and acHz = null or an integer (30..240).";
    }
    {
      assertion = builtins.isBool cfg.disableHdr;
      message = "display.disableHdr must be a boolean.";
    }
    {
      assertion = builtins.elem cfg.profile [
        "notebookcheck"
        "native"
        "custom"
      ];
      message = "display.profile must be notebookcheck, native, or custom.";
    }
    {
      assertion = cfg.profile != "custom" || cfg.iccProfile != null;
      message = "display.profile = custom requires display.iccProfile to point to your measured ICC file.";
    }
    {
      assertion = builtins.all validName (builtins.attrNames cfg.extraIccProfiles);
      message = "display.extraIccProfiles names may contain only letters, digits, underscores, and hyphens.";
    }
  ];

  # KWin/Wayland applies the profile selected in Display Configuration.
  # Installing an ICC in colord alone does not apply it to a Wayland display.
  xdg.dataFile = {
    "color/icc/framework/notebookcheck-MND508ZB1-1.icm".source = notebookcheck;
  }
  // lib.optionalAttrs (cfg.profile != "native" && selected != null) {
    "color/icc/framework-13-pro.icm".source = selected;
  }
  // lib.mapAttrs' (
    name: source: lib.nameValuePair "color/icc/framework/custom-${name}.icc" { inherit source; }
  ) cfg.extraIccProfiles;

  # Read the internal panel EDID before applying a borrowed calibration.
  home.packages = [
    pkgs.edid-decode
    pkgs.kdePackages.libkscreen
  ];

  # Use KWin's live API: never replace its monitor-layout/ICC state file.
  # Only change enabled eDP outputs that need it. KWin persists the result.
  systemd.user.services.framework-display-sdr = lib.mkIf policyEnabled {
    Unit = sessionUnit // {
      Description = "Apply built-in display SDR and optional refresh policy";
      # Brightness/monitor changes may write KWin's state several times.
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "oneshot";
      ExecStart = sdrPolicy;
      TimeoutStartSec = 120;
    };
    Install.WantedBy = [ "plasma-workspace-wayland.target" ];
  };

  # Recheck on saved display changes (including docking/lid transitions),
  # without a polling daemon. A no-op check does not rewrite KWin's state.
  systemd.user.paths.framework-display-sdr = lib.mkIf policyEnabled {
    Unit = sessionUnit // {
      Description = "Reapply built-in SDR policy after display changes";
    };
    Path.PathChanged = "${config.xdg.configHome}/kwinoutputconfig.json";
    Install.WantedBy = [ "plasma-workspace-wayland.target" ];
  };
}
