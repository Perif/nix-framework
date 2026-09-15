{ ... }:

{
  services.power-profiles-daemon.enable = true;

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
