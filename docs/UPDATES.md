# Update pinned dependencies

Run this on the installed laptop, or in the reviewed source you will deploy.
For new repository code, first follow [repository upgrades](install/upgrade.md).
Do not change `system.stateVersion` or `home.stateVersion` as a routine update.

## 1. Back up

```bash
sudo cp -a /etc/nixos "/etc/nixos.backup-$(date +%Y%m%d-%H%M%S)"
sudo cp -a /etc/nixos/flake.lock /etc/nixos/flake.lock.before-update
```

## 2. Update one intended input

Example: refresh packages within the configured Nixpkgs branch.

```bash
cd /etc/nixos
sudo nix flake update nixpkgs
```

To refresh all inputs deliberately, use `sudo nix flake update` instead.
Changing a release branch requires a separate compatibility review.

## 3. Review the lock change

```bash
diff -u /etc/nixos/flake.lock.before-update /etc/nixos/flake.lock
```

`diff` exits 1 when it finds changes. Confirm that changed repositories and
revisions are intended; inspect relevant upstream release/security notes.
Custom recipes with explicit versions/hashes, such as REA and Ollaya, also need
their recipe updated and tested; a lock update alone does not update them.

## 4. Build, verify and apply

Follow [the common change workflow](install/customization.md#2-evaluate-and-build)
from step 2. Keep its pause between temporary activation and promotion.
Use the reboot procedure for kernel/boot changes. Verify affected applications,
then keep the lock and source together in your trusted checkout.

**Expected:** evaluation, build and the relevant runtime checks succeed.
If they fail, restore the saved source/lock before the next rebuild; use the
previous boot generation if needed.

Earlier release work is retained in [historical notes](reference/update-history.md).
