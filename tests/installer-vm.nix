{ nixpkgs, disko }:
{ pkgs, lib, ... }:
let
  fixtureSettings = {
    hostname = "installer-target";
    diskDevice = "/dev/disk/by-id/nvme-QEMU_NVMe_Ctrl_INSTALL_TEST";
    timeZone = "UTC";
    features.secureBoot = false;
    user = {
      name = "owner";
      hashedPassword = null;
      initialPassword = null;
    };
  };
  # Use the same plain evaluator for the preloaded and guest-evaluated target.
  # Git flake metadata would otherwise differ from the guest's path inputs.
  target = import (nixpkgs + "/nixos/lib/eval-config.nix") {
    system = "x86_64-linux";
    specialArgs.settings = fixtureSettings;
    modules = [
      disko.nixosModules.disko
      ../hosts/framework-pro/disk.nix
      ./installer-vm/target.nix
    ];
  };
  fixtureFlake = pkgs.writeText "flake.nix" ''
    {
      inputs.nixpkgs.url = "path:${nixpkgs}";
      inputs.disko.url = "path:${disko}";
      inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
      outputs = { nixpkgs, disko, ... }: {
        packages.x86_64-linux.disko = disko.packages.x86_64-linux.default;
        nixosConfigurations.installer-target = import (nixpkgs + "/nixos/lib/eval-config.nix") {
          system = "x86_64-linux";
          specialArgs.settings = import ./settings.nix;
          modules = [ disko.nixosModules.disko ./disk.nix ./target.nix ];
        };
      };
    }
  '';
  lockedPath = input: {
    type = "path";
    path = toString input;
    inherit (input) narHash;
  };
  fixtureLock = pkgs.writeText "flake.lock" (
    builtins.toJSON {
      version = 7;
      root = "root";
      nodes = {
        root.inputs = {
          nixpkgs = "nixpkgs";
          disko = "disko";
        };
        nixpkgs = {
          locked = lockedPath nixpkgs;
          original = {
            type = "path";
            path = toString nixpkgs;
          };
        };
        disko = {
          inputs.nixpkgs = [ "nixpkgs" ];
          locked = lockedPath disko;
          original = {
            type = "path";
            path = toString disko;
          };
        };
      };
    }
  );
  source = pkgs.runCommand "installer-vm-source" { } ''
    mkdir "$out"
    cp ${fixtureFlake} "$out/flake.nix"
    cp ${fixtureLock} "$out/flake.lock"
    cp ${
      pkgs.writeText "settings.nix" (lib.generators.toPretty { } fixtureSettings)
    } "$out/settings.nix"
    cp ${../hosts/framework-pro/disk.nix} "$out/disk.nix"
    cp ${./installer-vm/target.nix} "$out/target.nix"
  '';
  # An actual ISO9660 mount plus a tmpfs root and EFI firmware exercise the
  # production live-environment guard without downloading an installer ISO.
  opticalFixture =
    pkgs.runCommand "installer-optical-fixture.iso" { nativeBuildInputs = [ pkgs.xorriso ]; }
      ''
        mkdir content
        echo 'Disposable installer regression fixture' > content/README
        xorriso -as mkisofs -V NIXOS_TEST -o "$out" content
      '';
  python = pkgs.python3.withPackages (p: [ p.pexpect ]);
  installerPackage = import ../pkgs/installer.nix { inherit pkgs; };
  qemu =
    (import (nixpkgs + "/nixos/lib/qemu-common.nix") {
      inherit lib;
      inherit (pkgs) stdenv;
    }).qemuBinary
      pkgs.qemu_test;
in
{
  name = "installer-recovery-boot";
  meta.timeout = 2400;
  nodes.installer = { lib, ... }: {
    virtualisation = {
      diskImage = null;
      memorySize = 4096;
      cores = 2;
      useEFIBoot = true;
      emptyDiskImages = [ (80 * 1024) ];
      # The sparse disposable image is exposed once, as a serial-numbered NVMe.
      qemu.drives = lib.mkForce [ ];
      qemu.options = [
        "-drive file=$(pwd)/empty0.qcow2,if=none,id=installtarget"
        "-device nvme,drive=installtarget,serial=INSTALL_TEST"
      ];
      additionalPaths = [
        source
        nixpkgs.outPath
        disko.outPath
        disko.packages.x86_64-linux.default
        target.config.system.build.toplevel
        target.config.system.build.destroyFormatMount
      ];
    };
    virtualisation.fileSystems."/iso" = {
      device = toString opticalFixture;
      fsType = "iso9660";
      options = [ "loop" "ro" "x-systemd.requires-mounts-for=/nix/store" ];
    };
    boot.kernelModules = [ "loop" ];
    boot.supportedFilesystems = [
      "btrfs"
      "vfat"
      "iso9660"
    ];
    environment.systemPackages = [
      installerPackage
      python
      pkgs.git
      pkgs.cryptsetup
      pkgs.lvm2
      pkgs.parted
      pkgs.gptfdisk
    ];
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = lib.mkForce [ ];
      connect-timeout = 1;
    };
  };
  testScript = ''
    import shlex
    import shutil
    from pathlib import Path

    installer.start()
    installer.wait_for_unit("multi-user.target", timeout=180)
    installer.wait_for_unit("iso.mount", timeout=120)
    installer.succeed("udevadm settle; test -b ${fixtureSettings.diskDevice}")
    installer.succeed("cp -r ${source} /root/config; chmod -R u+w /root/config")
    installer.succeed("git -C /root/config init -q; git -C /root/config add .; git -C /root/config -c user.name=Fixture -c user.email=fixture@example.com commit -qm fixture")
    with subtest("production preflight and plan on a clean target"):
        installer.succeed("installer --config /root/config preflight", timeout=300)
        installer.succeed("installer --config /root/config plan", timeout=300)
    with subtest("interactive partitioning and encrypted mount verification"):
        installer.succeed("${python}/bin/python ${./installer-vm/drive-stage.py} format", timeout=900)
        installer.succeed("installer --config /root/config mounts", timeout=300)
        installer.succeed("echo preserved > /mnt/home/recovery-canary; cp /mnt/etc/nix-framework-installer.json /root/original-record.json")
    with subtest("recover after interruption without reformatting"):
        # Only known target mounts and LVs in this disposable guest are touched.
        installer.succeed("swapoff /dev/vg/swap; umount -R /mnt; lvchange -an /dev/vg/root /dev/vg/swap; cryptsetup close cryptroot")
        installer.succeed("${python}/bin/python ${./installer-vm/drive-stage.py} recover", timeout=900)
        installer.succeed("grep -qx preserved /mnt/home/recovery-canary; cmp /root/original-record.json /mnt/etc/nix-framework-installer.json")
    with subtest("install and create login credentials"):
        installer.succeed("installer --config /root/config install", timeout=900)
        installer.succeed("${python}/bin/python ${./installer-vm/drive-stage.py} account", timeout=300)
        installer.succeed("sync")
    installer.shutdown()

    efi_vars = Path(installer.state_dir) / "installed-efi-vars.fd"
    shutil.copyfile("${pkgs.OVMF.variables}", efi_vars)
    efi_vars.chmod(0o600)
    boot_command = shlex.split("${qemu}") + [
        "-m", "2048", "-smp", "2",
        "-drive", f"file={installer.state_dir}/empty0.qcow2,if=none,id=installtarget",
        "-device", "nvme,drive=installtarget,serial=INSTALL_TEST",
        "-drive", "if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}",
        "-drive", f"if=pflash,format=raw,unit=1,readonly=off,file={efi_vars}",
    ]
    target = create_machine(start_command=shlex.join(boot_command), name="installed")
    driver.machines_qemu.append(target)
    with subtest("boot installed system from its EFI partition and unlock LUKS"):
        target.start()
        target.wait_for_console_text("[Pp]assphrase", timeout=180)
        target.send_console("disposable-vm-luks-passphrase\n")
        target.wait_for_unit("multi-user.target", timeout=180)
        target.succeed("findmnt -n -o FSTYPE / | grep -x btrfs; grep -qx preserved /home/recovery-canary")
        target.succeed("test -f /etc/nix-framework-installer.json")
    with subtest("authenticate with the password set by the account stage"):
        target.copy_from_host_via_shell("${./installer-vm/login.py}", "/tmp/test-login.py")
        target.succeed("python /tmp/test-login.py")
  '';
}
