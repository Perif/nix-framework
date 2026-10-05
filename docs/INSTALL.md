# Installation and maintenance guides

Choose a path before running commands. The clean-install stages are separate so
you can review each step and start a fresh shell between them. The format stage
is destructive and only for a fresh install from the supported NixOS UEFI ISO.
Existing systems must use the upgrade path and never run the format stage.

## Fresh installation

1. [Prepare the installer and verify the Git source](install/prepare.md).
2. [Configure settings and identify the drive](install/configure.md).
3. [Review the plan, format, verify mounts, and recover safely](install/storage.md).
4. [Install the system, set the account password, and reboot](install/system.md).
5. [Verify the first boot](install/first-boot.md).

Source stages default to the current reviewed checkout; pass `--config PATH`
to `preflight`, `plan`, `format`, `recover`, `mounts`, or `install` when it is elsewhere.
The `account` stage instead reads `/mnt/etc/nixos` directly. Each stage reads
settings afresh; there are no shell-variable handoffs. Review the source before
any `nix run` from that checkout. Untracked and ignored files are excluded from
the Git-backed snapshot.
In each new installer shell, enable the Nix CLI features before a flake
command:

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

## Existing installation and follow-up

- [Upgrade, including the one-time Ollama migration](install/upgrade.md).
- [Customize settings and safely rebuild](install/customization.md).
- [Enable signed Secure Boot](install/secure-boot.md), only after a stable
  installation and recovery path.
- [Repository and CI validation](install/validation.md).
- [Adversarial review findings and validation limits](install/review.md).
- Feature-specific guidance: [networking](NETWORKING.md),
  [audio](AUDIO.md), [display](DISPLAY.md),
  [local AI development](LOCAL-AI-DEVELOPMENT.md), and
  [security and privacy](SECURITY-PRIVACY.md).

## Links retained for older references

These headings preserve old `docs/INSTALL.md#...` links and route readers to the
new canonical page.

### 6. Evaluate before touching the disk

The old step numbering is retired. Use the complete staged path in order:
[configure](install/configure.md) → [plan and storage](install/storage.md) →
[install the system](install/system.md). Never run `format` on an existing
installation.

### 11. First-boot verification

Continue at [first-boot verification](install/first-boot.md).

### 12. Customize DNS, shells, and editors

Continue at [customization](install/customization.md).

### 13. Enable signed Secure Boot

Continue at [Secure Boot](install/secure-boot.md).

### 14. Routine safe rebuild workflow

Continue at [upgrade and routine rebuilds](install/upgrade.md).

### One-time model-storage migration for an existing installation

Continue at [the existing-system upgrade guide](install/upgrade.md).

### Normal rebuilds

Continue at [the existing-system upgrade guide](install/upgrade.md).

### References

See the references in the feature-specific guides linked above.
