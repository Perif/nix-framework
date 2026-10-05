# Plan, format, and verify storage

This page is for a **fresh install only**. Existing systems must use the
[upgrade guide](upgrade.md) and must never run `format`. Complete the
[nondestructive source and machine checks](prepare.md) and
[settings review](configure.md) first. The format command only runs from the
supported root shell on the standard NixOS UEFI installer ISO.

## Review the effective plan

Run the plan stage from the reviewed checkout. It reads the current settings
and checks the effective Disko target without executing Disko’s destructive
operations:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#installer -- plan
```

Read the full output. Confirm the host and exact target device match the
machine and drive you intend to erase. Record the `Reviewed base commit` and
`staged tree` values it prints. The Disko dry-run is an evaluation check, not a
visual partition preview. Resolve every evaluation error before continuing. If
you change any staged file, re-review and rerun `plan`.

The expected layout is a 1 GiB EFI partition, LUKS2, LVM, encrypted 40 GiB
swap, and Btrfs subvolumes for root, home, Nix, logs, snapshots, and Ollama
state. TRIM passthrough and swap discard are enabled. This can reveal which
encrypted SSD blocks are unused; for a maximum-confidentiality posture, review
`hosts/framework-pro/disk.nix` and its comments before installation.

## Format and mount

**Formatting destroys all data on the configured target.** Verify the device
identity again using the printed model, serial, size, resolved path, and current
signatures. Confirm backups and then invoke `format`:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#installer -- format
```

The command repeats environment and storage guards, displays the configured
stable device path, and requires typing `ERASE` followed by the exact device
path it prints before calling Disko. Compare its `Reviewed base commit` and
`staged tree` with the values from `plan`; if either differs, stop, review the
change, and rerun `plan`. The typed confirmation does not make the operation
safe if the path or source is wrong. Stop if there is any uncertainty. Enter
and securely retain a strong, unique LUKS passphrase when prompted.

Formatting is a one-time fresh-install stage, not a resume command. If it
reports an error or the shell is interrupted, do not run `format` again until
you have inspected the resulting device and resolved the failure. Use the
[manual recovery guidance](#manual-recovery-after-an-interrupted-format-or-mount)
below; it never calls Disko or erases data.

Run the separate mount verification stage:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#installer -- mounts
```

Review the result and retain the same reviewed source revision for `install`.
Expected mount points include `/mnt`, `/mnt/boot`,
`/mnt/home`, `/mnt/nix`, `/mnt/var/log`, `/mnt/.snapshots`, and
`/mnt/var/lib/private/ollama`. The active physical swap should be about 40 GiB
and inside the encrypted LVM layout. Do not install unless the target and all
expected mounts are correct.

## Manual recovery after an interrupted format or mount

The staged command intentionally does not auto-close mappings, deactivate
volume groups, unmount targets, or delete partial state. This prevents it from
making an uncertain condition worse. A failed `format` may have already
partitioned, encrypted, or formatted some of the target; never assume rollback.

1. Stop. Do not reboot into the target, rerun `format`, or issue broad cleanup
   commands. Record the exact error and leave unrelated disks alone.
2. Identify the selected stable path from `settings.nix`. Compare it with
   `lsblk`, `findmnt`, `swapon --show`, `sudo cryptsetup status cryptroot`,
   `sudo pvs`, `sudo vgs`, and `sudo lvs`. Some commands may report that an
   object does not exist; that is useful state information.
3. If any target partition is mounted, map the mount to its source and
   unmount only that verified target mount, deepest mount first. If swap is
   active on a verified target LV, turn off only that swap. Do not use a blanket
   unmount, swapoff, or volume-group deactivation command.
4. Close a LUKS mapping or deactivate a VG only after confirming that it belongs
   to this target and that no mount or swap still uses it. Never close a
   similarly named mapping or VG from another disk.
5. Choose the recovery path based on the inspected state:
   - If formatting completed and the expected filesystems and encrypted swap are
     mounted correctly, run `mounts` and then `install`. These stages verify the
     existing target and do not reformat it.
   - If the expected layout is present but some mounts are missing, mount only
     the verified filesystems from this target using the documented Disko
     layout, then run `mounts` and `install`. Do not run `preflight` or `plan`
     against active mappings/mounts; their fresh-disk guards intentionally
     refuse that state.
   - Run `preflight` and `plan` only if you have inspected and manually returned
     the target to a clean, unused state and have explicitly decided to restart
     the destructive fresh installation. They are not generic recovery checks.
     Only then may you consider `format` again after repeating the full identity
     and backup review.
   - If the state is unclear, preserve it and seek help with the command output.

The repository installer refuses active `cryptroot` mappings, a conflicting
`vg` volume-group name, and any mounted or active target descendant. It does
not automatically clean those up. This is intentional; do not bypass the
refusal.

Continue to [install the system](system.md).
