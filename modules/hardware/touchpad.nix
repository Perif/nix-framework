{ pkgs, ... }:

{
  systemd.services.touchpad-resume = {
    description = "Reset I2C touchpad after sleep";

    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];

    unitConfig.StopWhenUnneeded = true;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";

      ExecStop = pkgs.writeShellScript "reset-touchpad" ''
        ${pkgs.kmod}/bin/modprobe -r i2c_hid_acpi &&
        ${pkgs.kmod}/bin/modprobe i2c_hid_acpi
      '';
    };
  };
}
