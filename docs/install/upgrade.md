# Upgrade an existing installation

This path is for a system that is already installed. **Never run the fresh
install `format` stage or Disko on an existing system.** Back up irreplaceable
models and configuration before changing storage. If the actual filesystem or
volume layout differs from the one described here, stop and adapt the plan
before running a command.

## One-time Ollama storage migration

Fresh installations already create a dedicated `/ollama` Btrfs subvolume
mounted at `/var/lib/private/ollama`; they do not need this migration. Older
installations keep Ollama state under the root Btrfs subvolume. Create and
populate the separate subvolume before booting or activating the configuration
that mounts it.

First identify the current layout and model state:

```bash
findmnt /
sudo lvs -o lv_path,vg_name,lv_name
sudo blkid /dev/mapper/vg-root
systemctl show ollama.service -p ActiveState
sudo systemctl stop ollama.service
sudo systemctl mask --runtime ollama.service
sudo test -d /var/lib/private/ollama && sudo du -sh /var/lib/private/ollama
```

Before this migration, update a separate trusted Git checkout to the reviewed
revision that introduces the `/ollama` subvolume. The installed `/etc/nixos`
tree is writable but has no Git history. Compare its personalized `settings.nix`
with the trusted checkout and preserve local values; do not replace it blindly
with repository examples. Review the complete resulting tree, then copy the
intended revision into `/etc/nixos` before rebuilding.

Proceed only when `/dev/mapper/vg-root` is confirmed as the current Btrfs root
LV for this installation. If you have Ollama models or other state you expect
to preserve, require `/var/lib/private/ollama` to exist and inspect it before
copying. If it is absent or the layout is different, stop and locate the actual
state; do not create an empty destination and assume migration succeeded.
If you abort before rebooting, remove the runtime-only service mask after
confirming the old layout is still active:

```bash
sudo systemctl unmask --runtime ollama.service
```

If you have never used Ollama and confirm there is no existing state to retain,
you may follow the same process with an intentionally empty destination. Make
that choice explicit before creating the subvolume. The service is on-demand,
so an absent state directory can be normal on an unused installation.

For an existing data directory, use one shell session for the complete copy and
comparison. The top-level mount is temporary; the new subvolume name must not
already exist. The commands below preserve the old copy and do not format the
filesystem:

```bash
set -eu
MODEL_TOP="$(mktemp -d /tmp/ollama-subvolume.XXXXXX)"
sudo mount -o subvolid=5 /dev/mapper/vg-root "$MODEL_TOP"
sudo test ! -e "$MODEL_TOP/ollama"
sudo btrfs subvolume create "$MODEL_TOP/ollama"
sudo cp -a --reflink=auto /var/lib/private/ollama/. "$MODEL_TOP/ollama/"
sudo diff -qr /var/lib/private/ollama "$MODEL_TOP/ollama"
sudo btrfs filesystem sync "$MODEL_TOP"
sudo umount "$MODEL_TOP"
rmdir "$MODEL_TOP"
```

For the confirmed no-state case, run the same top-level mount and absence
check, then create the subvolume and unmount it; do not run `cp` or `diff`:

```bash
set -eu
MODEL_TOP="$(mktemp -d /tmp/ollama-subvolume.XXXXXX)"
sudo mount -o subvolid=5 /dev/mapper/vg-root "$MODEL_TOP"
sudo test ! -e "$MODEL_TOP/ollama"
sudo btrfs subvolume create "$MODEL_TOP/ollama"
sudo btrfs filesystem sync "$MODEL_TOP"
sudo umount "$MODEL_TOP"
rmdir "$MODEL_TOP"
```

If a command fails or is interrupted, do not repeat the subvolume creation or
copy blindly. Inspect `findmnt`, `btrfs subvolume list`, and the contents of the
old directory and top-level mount. Unmount only the verified temporary mount.
Delete a partial `/ollama` subvolume only after confirming it is the newly
created target, is not mounted or in use, and the old source remains intact. If
any of those checks is uncertain, preserve the state and get help.
If you stop the migration without rebooting, remove the runtime-only Ollama
service mask after verifying that the old layout remains the active storage:

```bash
sudo systemctl unmask --runtime ollama.service
```

After verifying the new subvolume exists, ensure the updated configuration is
present in `/etc/nixos`, then install it as the next boot generation:

```bash
(
set -eu
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild boot --flake ".#${INSTALL_HOST}"
sudo reboot
)
```

Do not activate this mount configuration before the subvolume exists. After
boot, confirm the new mount and model state before cleanup:

```bash
findmnt /var/lib/private/ollama
sudo stat -c '%a %U %G' /var/lib/private
sudo systemctl start ollama.service
sudo readlink -f /var/lib/ollama
ollama list
```

The mount should report `subvol=/ollama`, the private ancestor should be
`700 root root`, and the model list should be unchanged when there was prior
state. The old root-resident copy remains underneath the mount for recovery;
existing snapshots may retain it too. Do not delete it until the new store and
an independent backup are verified. Plan any cleanup separately from the active
subvolume.

## Routine upgrades and rebuilds

Keep a trusted Git checkout separate from the installed writable snapshot. Make
and review configuration changes there, preserve personalized settings, and
copy reviewed changes to `/etc/nixos` deliberately. The migration above is a
one-time prerequisite only for the old Ollama layout. Never rerun Disko for a
routine rebuild or upgrade.

Evaluate and activate temporarily first. This changes the running system but
leaves the previous boot default available:

```bash
(
set -eu
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
nix flake check --no-build --all-systems
sudo nixos-rebuild test --flake ".#${INSTALL_HOST}"
systemctl --failed
)
```

**Stop here and inspect the result before promotion.** `systemctl --failed`
lists failures but still exits successfully; it is not an automatic health gate.
Check networking/DNS, a new terminal and login, audio, display, and any services
you enabled. Start on-demand AI services explicitly if they are part of your
checks. Resolve unexpected failed units and inspect their logs. A successful
temporary activation alone does not test the new kernel or initrd.

Only after those checks succeed, promote the same reviewed configuration in a
separate command. Do not edit or update its lock between testing and promotion:

```bash
(
set -eu
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild switch --flake ".#${INSTALL_HOST}"
)
```

Use the previous generation from the systemd-boot menu if a new generation
cannot boot. Feature-specific post-update checks are in
[customization and rebuilds](customization.md) and the relevant guide under
`docs/`.
