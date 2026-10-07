{
  config,
  lib,
  pkgs,
  settings,
  ...
}:

let
  limit = settings.power.chargeLimit;
  chargeLimit = pkgs.writeShellApplication {
    name = "framework-charge-limit";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./scripts/charge-limit.sh;
  };
in

{
  assertions = [
    {
      assertion = limit == null || (builtins.isInt limit && limit >= 1 && limit <= 100);
      message = "power.chargeLimit must be null or an integer from 1 to 100.";
    }
    {
      # The module below is out-of-tree; nixos-hardware's framework/kmod.nix
      # (hardware.framework.enableKmod) adds it for kernels >= 6.10. Without it
      # systemd-modules-load would fail at every boot.
      assertion =
        limit == null
        || lib.any (package: lib.getName package == "framework-laptop-kmod") config.boot.extraModulePackages;
      message = "power.chargeLimit needs the framework_laptop kernel module; keep nixos-hardware's hardware.framework.enableKmod on or set power.chargeLimit = null.";
    }
  ];

  services.power-profiles-daemon.enable = true;

  boot.kernelModules = lib.optional (limit != null) "framework_laptop";
  systemd.services.framework-charge-limit = lib.mkIf (limit != null) {
    description = "Set the Framework battery charge limit";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${chargeLimit}/bin/framework-charge-limit /sys/class/power_supply ${toString limit}";
      ProtectHome = true;
      ProtectSystem = "strict";
      NoNewPrivileges = true;
    };
  };

  # Disko's swap content has resumeDevice = true, so the 40 GiB LVM swap
  # LV is declared as the hibernation resume device.
  #
  # systemd.sleep.extraConfig was removed in NixOS 26.05; sleep.conf is
  # now expressed as structured settings.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "yes";
    AllowHibernation = "yes";
    AllowSuspendThenHibernate = "yes";
    HibernateDelaySec = "60min";
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
    HandlePowerKey = "suspend-then-hibernate";
  };

  # Fast compressed swap for ordinary memory pressure. Hibernation goes
  # to the encrypted physical swap LV, not to zram.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
    priority = 100;
  };
}
