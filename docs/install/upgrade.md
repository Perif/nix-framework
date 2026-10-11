# Upgrade an existing installation

**Never run Disko or the installer's `format` stage on the installed system.**
Choose the path you need:

- Settings/packages already in your source: [apply a change](customization.md).
- New package versions: [update pinned inputs](../UPDATES.md).
- New repository code: follow the steps below.
- Old Ollama storage under the root subvolume:
  [migrate before activating the new mount](ollama-migration.md).

## Update repository code

The installer copies `/etc/nixos` without `.git`. Keep a separate trusted Git
checkout for reviewing upstream changes; `git pull` in `/etc/nixos` is not the
update procedure.

1. Back up the installed source:

```bash
sudo cp -a /etc/nixos "/etc/nixos.backup-$(date +%Y%m%d-%H%M%S)"
```

2. In your trusted checkout, fetch and select the exact reviewed revision:

```bash
git fetch origin
git checkout --detach REVIEWED_COMMIT
```

Stop if the checkout has uncommitted work. Confirm the repository and commit
before proceeding. If you need a checkout, use the source-review steps in
[preparation](prepare.md#1-prepare-the-installer), in a user-owned directory.

3. Compare the new source with `/etc/nixos`. Review upstream changes and merge
   new settings into your existing values. Preserve hostname, disk, username,
   timezone, Git identity and custom profile/package paths. Do not replace
   `settings.nix` with repository defaults.
4. Copy the reviewed changed files to matching paths in `/etc/nixos`. Copy any
   newly referenced source files too. Remove an obsolete file only after
   confirming no retained local module imports it. Keep custom files and secrets
   out of broad replacement commands.
5. Follow [apply a change](customization.md). Use its reboot procedure if the
   update changes the kernel, storage or bootloader.

**Expected:** the new generation passes verification with your personal values
intact. Keep the old source backup and a working boot generation until then.

## One-time Ollama storage migration

The complete, non-formatting procedure is now on
[the dedicated migration page](ollama-migration.md). Fresh installations do not
need it. Do not activate a mount for `/ollama` before that subvolume exists.

## Routine upgrades and rebuilds

Use [the common change workflow](customization.md), including its separate
verification and promotion steps.
