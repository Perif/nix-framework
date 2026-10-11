# 3. Plan and format storage

**Fresh installation only.** Complete [configuration](configure.md). Stay in the
root shell at `/tmp/nixos-config`. Never use `format` for recovery or upgrades.

## 1. Review the plan

```bash
nix run .#installer -- plan
```

Confirm the hostname and exact disk identity. Record the printed **Reviewed
base commit** and **staged tree**. Read the full output and resolve all errors.
The Disko dry-run evaluates the plan; it is not a visual partition preview.
If you change any source, stage it, review it and rerun `plan`.

## 2. Erase the selected drive

**This destroys all data on the configured disk.** Confirm your backup, model,
serial, size and resolved device path before proceeding.

```bash
nix run .#installer -- format
```

Before typing the confirmation, compare the displayed base commit and staged
tree with your plan. If either differs, stop and re-review. Enter exactly
`ERASE <the printed by-id path>`, then choose and securely retain a strong LUKS
passphrase when prompted.

If formatting fails or is interrupted, **do not repeat it**. Use
[recovery](recovery.md) to inspect and resume the existing layout.

## 3. Verify the mounts

```bash
nix run .#installer -- mounts
```

**Expected:** successful verification of `/mnt`, `/mnt/boot`, `/mnt/home`,
`/mnt/nix`, `/mnt/var/log`, `/mnt/.snapshots` and
`/mnt/var/lib/private/ollama`, with encrypted swap active. Default swap is 40 GiB.
Keep the same reviewed source for installation.

**Next:** [4. Install and set the password](system.md).

## Recover an existing formatted target

Moved to [the recovery procedure](recovery.md). Never rerun `format` to resume.

## Inspect an interrupted format or mount

Follow [recovery: inspect first](recovery.md#1-inspect-first).
