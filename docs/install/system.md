# Install the system and set the login password

Complete the [storage plan, format, and mount checks](storage.md). Do not run
this page unless `mounts` confirmed the expected fresh-install layout under
`/mnt`.

## Install the reviewed snapshot

The install stage rechecks the mount sources and required subvolumes, copies the
reviewed Git-backed configuration snapshot to `/mnt/etc/nixos` without `.git`
history, and runs `nixos-install` against that installed snapshot. Its reported
base commit and staged-tree identity should match the revision reviewed before
formatting; if the source changed, stop and review it before installing. The
stage does not rely on shell variables from another stage and does not reboot
automatically.

The persistent `/mnt/etc/nix-framework-installer.json` record must match the
selected source, disk and evaluated storage layout. Preserve it; do not remove
it to bypass a mismatch. After interruption, use the guarded `recover` stage
described in the storage guide before retrying installation.

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#installer -- install
```

Stop if it reports that `/mnt` is backed by an unexpected device, that a
required subvolume is missing, or that the reviewed source does not match. Do
not rerun `format` because an install failed. Correct the non-destructive issue
and rerun `install` only after reviewing the state. The installed tree is a
writable source snapshot without Git history; keep your trusted checkout
separately for future updates. Preserve your personalized settings when
updating it.

## Set and verify the password

The account stage reads the hostname and login name from
`/mnt/etc/nixos/settings.nix`, checks that the installed account and system
generation exist, and sets the password in the target. It runs from the installed configuration snapshot, does not require Git metadata,
and does not reboot:

```bash
sudo -i
cd /mnt/etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run /mnt/etc/nixos#installer -- account
```

When both password settings are `null`, enter a strong login password when
prompted. Confirm the account status is usable. If you intentionally set a
`hashedPassword`, the stage verifies the existing account and status without
asking for another password. The LUKS passphrase remains separate.

## Reboot

Only after installation and account verification succeed, flush pending writes
and reboot. Remove the installer USB when firmware starts:

```bash
sync
reboot
```

At cold boot, enter the LUKS passphrase and then log in through SDDM with the
account password. Continue to the [first-boot checks](first-boot.md).
