{
  config,
  lib,
  ...
}:

{
  assertions = [
    {
      assertion =
        lib.hasPrefix "/dev/disk/by-id/" config.disko.devices.disk.main.device
        && !(lib.hasInfix "REPLACE" config.disko.devices.disk.main.device)
        && builtins.match ".*-part[0-9]+" config.disko.devices.disk.main.device == null;
      message = ''
        hosts/framework-pro/disk.nix must use a verified whole-disk
        /dev/disk/by-id path, not a partition, before running Disko.
      '';
    }
  ];

  disko.devices = {
    disk.main = {
      type = "disk";

      # The assertion above rejects the checked-in destructive-install sentinel.
      device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_2TB_S7U7NU0YB37482T";

      content = {
        type = "gpt";

        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";

            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          cryptroot = {
            size = "100%";

            content = {
              type = "luks";
              name = "cryptroot";

              # Interactive passphrase entry during destructive Disko setup.
              askPassword = true;

              # Explicitly request LUKS2.
              extraFormatArgs = [
                "--type"
                "luks2"
              ];

              settings = {
                # Enables TRIM passthrough. See README security note.
                allowDiscards = true;
              };

              content = {
                type = "lvm_pv";
                vg = "vg";
              };
            };
          };
        };
      };
    };

    lvm_vg.vg = {
      type = "lvm_vg";

      lvs = {
        # 32 GiB RAM with margin for hibernation.
        swap = {
          size = "40G";

          content = {
            type = "swap";
            resumeDevice = true;
            discardPolicy = "both";
          };
        };

        root = {
          size = "100%FREE";

          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "nixos"
            ];

            subvolumes = {
              "/root" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "ssd"
                ];
              };

              "/home" = {
                mountpoint = "/home";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "ssd"
                ];
              };

              "/nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "ssd"
                ];
              };

              "/log" = {
                mountpoint = "/var/log";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "ssd"
                ];
              };

              # DynamicUser StateDirectory=ollama lives here on the host;
              # /var/lib/ollama is systemd's public symlink, not a mount target.
              "/ollama" = {
                mountpoint = "/var/lib/private/ollama";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "ssd"
                ];
              };

              "/snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "ssd"
                ];
              };
            };
          };
        };
      };
    };
  };
}
