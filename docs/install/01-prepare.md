# 1. Prepare the installer

Guide 01 · [All guides](../README.md).

1. Back up the target disk. Create a USB using the standard stable
   [NixOS graphical installer ISO](https://nixos.org/download/).
2. Disable firmware Secure Boot for installation. Boot the USB's **UEFI** entry
   and select the **non-LTS kernel**, as directed by the
   [Framework installation guide](https://guides.frame.work/Guide/NixOS+on+the+Framework+Laptop+13+Pro/780?lang=en).
   Use the terminal procedure below; do not launch the graphical disk installer.
3. Open a terminal and enter a root shell:

```bash
sudo -i
test -d /sys/firmware/efi/efivars
```

Stop if the UEFI check fails. Reboot the USB in UEFI mode.

4. Connect to Wi-Fi if needed, verify connectivity and check the clock:

```bash
nmtui
curl --fail --head https://cache.nixos.org/
timedatectl status
export NIX_CONFIG="experimental-features = nix-command flakes"
```

5. Clone into a new directory. If the destination already exists, choose another
   path and use it throughout these instructions.

```bash
(
set -eu
test ! -e /tmp/nixos-config
git clone https://github.com/Perif/nix-framework.git /tmp/nixos-config
)
cd /tmp/nixos-config
```

6. Replace `REVIEWED_COMMIT` below with the exact commit you reviewed. Verify the
   remote, commit and checked-in source **before executing this repository**.
   `less` opens each complete file; press `:n` for the next file and `q` to quit.

```bash
git checkout --detach REVIEWED_COMMIT
git remote -v
git log -1 --oneline
git status --short
less flake.nix flake.lock settings.nix hosts/framework-pro/disk.nix pkgs/installer.nix scripts/installer/*.py
```

**Expected:** the intended repository and commit, with no local changes. Review
all installer sources, including layout derivation and record validation.
A clean `git diff` does not show the checked-in source.

Keep `.git`: the installer requires a Git-backed source snapshot. Source symlinks
are unsupported. Untracked/ignored files are excluded; deliberately stage any
needed custom files later. Never put passwords, private keys or VPN secrets in
this source: tracked files enter the world-readable Nix store.

**Next:** [2. Configure](02-configure.md).
