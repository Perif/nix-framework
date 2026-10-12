# Resume an interrupted installation

Use this only from the standard NixOS UEFI installer USB, with the same reviewed
Git checkout and personalized settings. **Do not rerun `format` or Disko.**
If you rebooted the USB, recover your trusted checkout including `.git` and
staged settings before continuing.

## 1. Inspect first

Open a root shell. Record the original error and inspect the current state:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
findmnt
swapon --show
cryptsetup status cryptroot
pvs
vgs
lvs
```

Some objects may not exist yet. Match every relevant device to the exact
`diskDevice` in `settings.nix`. Do not issue blanket unmount, swapoff, mapping
close or volume-group cleanup commands.

- Complete layout, correct mounts and matching installer record: go to step 3.
- Complete layout but missing installer record: use step 2.
- Complete layout, closed mapping or missing mounts: use step 2.
- Missing filesystem/subvolume, conflicting device or unclear state: stop and
  inspect with help. Recovery does not complete partial formatting.

`preflight` and `plan` are fresh-disk checks; they intentionally reject active
mappings and mounts. They are not recovery commands.

## 2. Open and mount the existing layout

```bash
nix run .#installer -- recover
```

Check the displayed disk identity, then type `RECOVER <the printed by-id path>`.
The command verifies the expected GPT/LUKS2/LVM/Btrfs layout, keeps correct
mounts and mounts missing ones. It does not create filesystems or erase data.
If it fails partway, preserve the state and inspect the error before retrying.

Preserve `/mnt/etc/nix-framework-installer.json`. It binds the disk, storage
layout and reviewed source. Do not delete it to bypass a mismatch. Recovery
validates an existing record; it creates a missing one only for a fully verified
layout without an existing installation/configuration.

## 3. Verify and resume

```bash
nix run .#installer -- mounts
```

After that succeeds, follow [install and account setup](system.md). If the
reviewed source changed to fix an installation failure, `install` shows the old
and new identities and requires `REPLACE SOURCE <first 12 characters of the
current tree>`. Review the change before accepting it; the disk/layout must
still match the record. The confirmation replaces the target configuration.

Never assume a failed format rolled back. A destructive restart is a separate
fresh installation requiring full disk identification and backup review.
