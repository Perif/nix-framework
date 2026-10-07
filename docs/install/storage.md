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

The storage contract is read from the evaluated Disko module in
`hosts/framework-pro/disk.nix`; the installer derives the mount set and sizes
from it. Unsupported topology changes are rejected before erasure. With the
default 1 GiB EFI and 40 GiB swap, the capacity guard requires at least 57 GiB
(including 16 GiB of space for root and layout overhead). This is a feasibility
floor; the complete desktop, builds, models and snapshots need substantially
more space. The expected layout is a 1 GiB EFI partition, LUKS2, LVM, encrypted 40 GiB
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
[recovery guidance](#recover-an-existing-formatted-target)
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

## Recover an existing formatted target

When the existing GPT/LUKS/LVM/Btrfs layout is complete but closed or partially
mounted, use the same reviewed Git checkout and personalized settings:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#installer -- recover
```

Review the displayed disk identity and type `RECOVER` followed by the exact
by-id path when prompted. The command validates GPT partition numbers, labels
and the EFI type, opens only the expected LUKS2 partition, activates only the
expected LVs, retains correct existing mounts, mounts missing subvolumes and
the exact EFI partition, and enables the expected encrypted swap. It never
calls Disko, creates filesystems, or formats a partition. Incorrect filesystems,
unrelated mappings, conflicting mounts, and a record for another disk or layout
stop recovery. If it stops partway, preserve the state and inspect it before retrying.

Successful format/recovery records the source tree/base commit, immutable source
path, disk identity and layout fingerprint in
`/mnt/etc/nix-framework-installer.json` (root-readable; no credentials).
Installation requires a record for the same disk and layout. If the reviewed
source changed since formatting (for example a fix after a failed
`nixos-install`), `install` prints the recorded and current source and requires
typing `REPLACE SOURCE <first 12 characters of the current tree>`; only then
does it replace the copied configuration on the target and re-bind the record.
Without a terminal it stops instead. Recovery validates the disk and layout of
an existing record and never replaces it; when an interruption happened before
record creation, it creates one only after the entire layout passes
verification. Preserve the record with your reviewed source for
troubleshooting. It is provenance metadata, not authentication against someone
who can alter the disk as root.

After recovery, run `mounts`, `install`, and `account` as applicable. A partially
formatted target missing required filesystems or subvolumes needs manual
inspection; recovery cannot finish formatting it.

## Inspect an interrupted format or mount

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
   - If the expected layout is present but some mounts are missing, use the
     guarded `recover` command above, then run `mounts` and `install`.
     Do not run `preflight` or `plan`
     against active mappings/mounts; their fresh-disk guards intentionally
     refuse that state.
   - Run `preflight` and `plan` only if you have inspected and manually returned
     the target to a clean, unused state and have explicitly decided to restart
     the destructive fresh installation. They are not generic recovery checks.
     Only then may you consider `format` again after repeating the full identity
     and backup review.
   - If the state is unclear, preserve it and seek help with the command output.

The fresh-format stage refuses active `cryptroot` mappings, a conflicting
`vg` volume-group name, and any mounted or active target descendant. It does
not automatically clean those up. This is intentional; do not bypass the
refusal.

Continue to [install the system](system.md).
