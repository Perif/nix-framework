# 4. Install and set the password

Continue only after [mount verification](03-storage.md) succeeds. Stay in the root
shell at `/tmp/nixos-config` with the same reviewed source.

## 1. Install

```bash
nix run .#installer -- install
```

**Expected:** the source identities match your plan and installation completes.
The installer rechecks mounts and provenance, then copies the reviewed snapshot
to `/mnt/etc/nixos` without Git history. Preserve the trusted checkout for updates.

If the source changed, review the displayed old/new identities before accepting
`REPLACE SOURCE <tree>`. Keep `/mnt/etc/nix-framework-installer.json`. On failure,
use [recovery](recovery.md); do not rerun `format`.

## 2. Set and verify the login password

```bash
nix run /mnt/etc/nixos#installer -- account
```

Enter a strong login password when prompted. It is separate from the LUKS
passphrase. **Expected:** the target account exists and its password status is
usable. If you deliberately configured a password hash, this step verifies it
instead of prompting. Do not reboot if account verification fails.

## 3. Reboot

Only after both stages succeed:

```bash
sync
reboot
```

Remove the USB when firmware starts. Enter the LUKS passphrase at boot, then the
account password at the login screen.

**Next:** [5. Verify first boot](05-first-boot.md).
