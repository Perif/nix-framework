{
  config,
  lib,
  settings,
  ...
}:

{
  assertions = [
    {
      assertion =
        lib.hasPrefix "/dev/disk/by-id/" config.disko.devices.disk.main.device
        && config.disko.devices.disk.main.device != "/dev/disk/by-id/REPLACE-WITH-YOUR-NVME-ID";
      message = ''
        settings.nix: replace diskDevice with the verified /dev/disk/by-id/...
        path for the installation target before running Disko.
      '';
    }
  ];

  disko.devices = {
    disk.main = {
      type = "disk";

      # The assertion above rejects the checked-in destructive-install sentinel.
      device = settings.diskDevice;

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
