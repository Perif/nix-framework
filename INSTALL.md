# Install and maintain this NixOS configuration

Choose the path that matches the machine. Read the linked guide before running
its commands. Fresh installation is supported from a root shell on the standard
NixOS UEFI installer ISO. Existing installations must never run the fresh-format
path.

- **New installation:** [installation guide](docs/INSTALL.md) → prepare the
  source → [configure](docs/install/configure.md) → [inspect the storage plan and
  format](docs/install/storage.md) → [install and set the account password](docs/install/system.md)
  → [first boot](docs/install/first-boot.md).
- **Already running this configuration:** [upgrade and model-storage migration](docs/install/upgrade.md).
- **Enable signed Secure Boot after a stable installation:**
  [Secure Boot guide](docs/install/secure-boot.md).
- **Evaluate and test repository changes:** [validation guide](docs/install/validation.md).

The installer’s `format` stage is destructive and fresh-install-only. It has
additional target checks and requires typing the configured device path, but
those checks do not replace your own disk-identity review. Stop whenever the
machine, device, source revision, or current data is uncertain. Keep an
independent backup of anything you need.

For managed settings after installation, start with
[customization and rebuilds](docs/install/customization.md). Feature-specific
procedures remain in the linked guides under `docs/`.
