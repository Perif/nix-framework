# Prepare the installer and verify the source

This path is for a fresh installation on the Framework Laptop described by this
repository. For an existing installation, use [the upgrade path](upgrade.md).
Never run the fresh-install `format` stage on an installed system.

## Supported environment

Use the standard NixOS stable installer ISO, boot its UEFI entry with firmware
Secure Boot disabled, and open a root shell. The staged installer supports this
NixOS installer environment; it does not support netboot images, another Linux
live system, or running the destructive stage from an installed NixOS system.

```bash
sudo -i
test -d /sys/firmware/efi/efivars
```

If the UEFI check fails, stop and reboot the installer in UEFI mode. For Wi-Fi,
connect with NetworkManager’s text interface and check that the Nix cache is
reachable and the live clock is plausible:

```bash
nmtui
curl --fail --head https://cache.nixos.org/
timedatectl status
export NIX_CONFIG="experimental-features = nix-command flakes"
nix --version
```

## Obtain and review a Git checkout

Clone the repository at the revision you intend to install. Prefer a clone over
copying a folder from another drive:

```bash
(
set -eu
test ! -e /tmp/nixos-config
git clone REPLACE_WITH_TRUSTED_REPOSITORY_URL /tmp/nixos-config
cd /tmp/nixos-config
)
```

If `/tmp/nixos-config` already exists, stop and choose a new destination; do not
reuse an old checkout or remove it without checking whether it contains work.
Update the remaining examples if you choose a different destination.

Before running any Nix command from this checkout, verify that the repository
and revision came from a source you trust. Compare the commit ID with the
intended reviewed revision, and check out that exact revision if necessary.
Inspect the repository identity, commit, changes, `flake.nix`, `flake.lock`, `settings.nix`, host disk definition,
and the installer implementation. Confirm the `format` stage’s behavior from
this reviewed revision. Do not execute an installer copied from an unreviewed
source.

```bash
(
set -eu
cd /tmp/nixos-config
git remote -v
git status --short
git log -1 --oneline --decorate
git diff -- flake.nix flake.lock settings.nix hosts/framework-pro/disk.nix
sed -n '1,180p' pkgs/installer.nix
sed -n '1,220p' scripts/installer/cli.py
sed -n '1,180p' scripts/installer/storage.py
sed -n '1,180p' scripts/installer/common.py
)
```

The installer takes a Git-backed flake snapshot. Untracked and ignored files
are excluded, and the installed snapshot contains no `.git` history. Source
symlinks are unsupported; copy any reviewed profile or package files into the
checkout and update their references before staging. Tracked or staged files
are still part of the source and are not private: never put private keys, VPN
profiles, plaintext passwords, or other secrets in the source or Nix store. A
declarative password hash is also copied into the world-readable Nix store and
should be avoided.

Use the clone with its Git metadata intact. A folder copy without `.git` is
not a supported source; if network access is unavailable, transfer the complete
trusted clone including `.git` rather than copying only the visible files.

The `preflight` command also evaluates settings, so run it only after completing
[configuration](configure.md), including setting and staging `diskDevice` and a
non-null timezone. Each stage can run in a new root shell from the reviewed checkout; return to
`/tmp/nixos-config` and export `NIX_CONFIG` first.

Continue to [configure the installation](configure.md).
