# Install and customize this NixOS build

This is the root-level start guide. The complete executable procedure—including
repeated disk identity checks, the destructive Disko command, password setup,
Secure Boot enrollment, and every first-boot check—is
[docs/INSTALL.md](docs/INSTALL.md). Read that guide before erasing a drive; do
not run a Disko command copied without its preceding verification steps.

Already installed? Before activating this revision, follow the
[Ollama storage migration](docs/INSTALL.md#one-time-model-storage-migration-for-an-existing-installation).
Do not rerun the installation or Disko steps on an existing system.

## 1. Prepare the installer

Boot the current NixOS installer in UEFI mode, connect to the network, and
enable the flake commands:

```bash
sudo -i
test -d /sys/firmware/efi/efivars
nmtui
curl --fail --head https://cache.nixos.org/
export NIX_CONFIG="experimental-features = nix-command flakes"
```

Clone or copy this repository into the installer's temporary filesystem:

```bash
git clone REPLACE_WITH_REPOSITORY_URL /tmp/nixos-config
cd /tmp/nixos-config
test -f flake.nix
test -f flake.lock
```

Do not update `flake.lock` during installation.

## 2. Identify the installation drive

List whole drives and stable NVMe identifiers:

```bash
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN
ls -l /dev/disk/by-id/nvme-* | grep -v -- '-part'
```

For this build, expect a `Samsung SSD 990 EVO Plus 2TB` (model family
`MZ-V9S2T0`). A 2,000 GB drive normally appears as about 1.82 TiB. This model
does not advertise WWN support, so an `nvme-eui.*` link is not guaranteed.

Set the exact model-and-serial link printed by the command above and verify it.
The following value is a placeholder, not a literal path:

```bash
INSTALL_DISK="/dev/disk/by-id/REPLACE_WITH_THE_EXACT_NVME_LINK"
test -b "$INSTALL_DISK"
readlink -f "$INSTALL_DISK"
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS "$INSTALL_DISK"
wipefs --no-act "$INSTALL_DISK"
```

Stop if the model, serial, size, or current contents are not the intended disk.

## 3. Edit the installation settings

Open `settings.nix` and replace the disk, account, regional, and Git identity
values. Keep both password fields `null` for the preferred install path.
The following is an excerpt to edit in place, not a replacement file: retain
the existing `power`, `network`, `ai`, `display`, `audio` and
`features.thunderbolt` settings.

```nix
{
  hostname = "framework-pro";
  timeZone = "America/Chicago";
  defaultLocale = "en_US.UTF-8";
  consoleKeyMap = "us";

  dns = {
    providerName = "Cloudflare 1.1.1.1 (unfiltered)";
    servers = [
      "1.1.1.1#one.one.one.one"
      "1.0.0.1#one.one.one.one"
      "2606:4700:4700::1111#one.one.one.one"
      "2606:4700:4700::1001#one.one.one.one"
    ];
    dohUrl = "https://cloudflare-dns.com/dns-query";
    bootstrapIps = [ "1.1.1.1" "1.0.0.1" ];
    filtering = {
      enable = true;
      blocklistUrls = [
        "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/normal.txt"
        "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif.txt"
      ];
      allowlist = [ ];
    };
  };

  diskDevice = "/dev/disk/by-id/REPLACE_WITH_THE_EXACT_NVME_LINK";

  user = {
    name = "py";
    description = "REPLACE WITH YOUR DISPLAY NAME";
    hashedPassword = null;
    initialPassword = null;
    sshAuthorizedKeys = [ ];
  };

  features = {
    qbz = true;
    secureBoot = false;
  };

  git = {
    userName = "REPLACE WITH YOUR GIT NAME";
    userEmail = "REPLACE_WITH_YOUR_EMAIL@example.com";
  };
}
```

The explicit IANA time zone controls Plasma without GeoClue. Change it and
rebuild when travelling; keep the Plasma clock widget set to **Local**.

## 4. Evaluate before erasing anything

Read the selected values back from Nix and confirm the two disk values match:

```bash
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
INSTALL_USER="$(nix eval --raw --impure --expr '(import ./settings.nix).user.name')"
CONFIGURED_DISK="$(nix eval --raw --impure --expr '(import ./settings.nix).diskDevice')"
test "$INSTALL_DISK" = "$CONFIGURED_DISK"
nix flake check --no-build --all-systems
nix eval --raw ".#nixosConfigurations.${INSTALL_HOST}.config.system.build.toplevel.drvPath"
```

Continue with [docs/INSTALL.md step 6](docs/INSTALL.md#6-evaluate-before-touching-the-disk).
It validates Disko without running it, repeats the device checks, performs the
destructive formatting step, verifies the encrypted layout, and installs the
evaluated configuration.

## 5. Set the password before rebooting

After `nixos-install` completes and while `/mnt` is still mounted:

```bash
nixos-enter --root /mnt -c "passwd ${INSTALL_USER}"
nixos-enter --root /mnt -c "passwd --status ${INSTALL_USER}"
```

The status must show `P`, not `L`. The password never enters the flake or Nix
store.

## 6. Verify the first boot

Run the full checklist in
[docs/INSTALL.md step 11](docs/INSTALL.md#11-first-boot-verification). At minimum:

```bash
systemctl --failed
timedatectl status
findmnt /
swapon --show
systemctl is-active blocky.service
systemctl is-active smartd.service
resolvectl status
ss -lntup | grep ':5353'
powerprofilesctl get
nix config show allowed-users
nix config show trusted-users
```

Blocky must listen only on `127.0.0.1:5353` and `[::1]:5353`. Nix daemon access
must contain only `root` and `settings.user.name`; only `root` is trusted.

## 7. Verify the development profile

Xbox Elite Series 2 support is included over USB-C and Bluetooth. Bluetooth
remains off at boot; enable it in Plasma before pairing. Follow
[the controller guide](docs/CONTROLLERS.md) for pairing and input verification.

```bash
codium --list-extensions
python --version
basedpyright --version
ruff --version
go version
gopls version
dlv version
rustc --version
cargo --version
rust-analyzer --version
command -v vim nvim sublime_text
```

VSCodium has one local agent extension—Continue—and pinned Nix, Python, Go,
Rust, YAML, TOML, EditorConfig, and debugger extensions. Continue sends model
requests only to the loopback Ollama and llama.cpp profiles. Start and stop the
on-demand Ollama service with:

```bash
ollama-on
ollama-status
ollama-off
```

See [docs/LOCAL-AI-DEVELOPMENT.md](docs/LOCAL-AI-DEVELOPMENT.md) before pulling
a model or changing its context limit.

## 8. Complete Sublime's one-time package bootstrap

Sublime is pinned to stable build 4213 independently of the system lock.
After rebuilding, `subl --version` should report 4213. Python 3.3 is explicitly
disabled and its host removed; do not re-enable it for outdated plugins.

Launch Sublime Text, select **Tools > Install Package Control**, and restart it.
The managed settings then install only EditorConfig, LSP, the syntax-only Nix
package, and Package Control. The Python, Go, Rust, and Nix language servers are
pinned Nix binaries; Sublime plug-ins do not download them.

Those four Package Control packages update outside Nix once per day and are not
rolled back with a Nix generation. This is an installation list, not an enforced
allowlist; manually installed packages are not prohibited. Keep the set small.
VSCodium remains the fully immutable extension profile.

Open a `.py`, `.go`, `.rs`, and `.nix` file in a project. Confirm that LSP shows
BasedPyright/Ruff, gopls, rust-analyzer, and nixd respectively. The obsolete
Python 3.3 plug-in host is intentionally unavailable.

## 9. Customize declaratively

Edit source files, not generated `$HOME/.config` links:

- DNS filter, allowlist, host/user/region: `settings.nix`
- Blocky service: `modules/nixos/dns-filter.nix`
- VSCodium extensions/settings/local models: `home/modules/vscodium.nix`
- Vim and Neovim: `home/modules/vim.nix`
- Sublime preferences, package set, and LSP clients: `home/modules/sublime.nix`
- Nix and Ollama aliases: `home/modules/zsh.nix`

For a Blocky false positive, first confirm the site works in Firefox, then add
a narrow declarative exception:

```nix
dns.filtering.allowlist = [
  "example.com"
  "*.example.com"
];
```

For project formatting, commit an `.editorconfig` instead of overriding every
editor globally:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
```

Detailed customization and recovery procedures are in
[docs/INSTALL.md step 12](docs/INSTALL.md#12-customize-dns-shells-and-editors) and
[docs/NETWORKING.md](docs/NETWORKING.md).

## 10. Test and promote every change

If upgrading an already installed version, first follow the
[one-time model-storage migration](docs/INSTALL.md#one-time-model-storage-migration-for-an-existing-installation).
It copies existing Ollama state into a separate Btrfs subvolume without
reformatting or deleting the old copy. Do not activate the new mount before
that subvolume exists. Fresh Disko installs require no migration.

This revision also caps EFI boot retention at three generations in both boot
modes, inherits the locale from `settings.nix`, and adds persistent SMART
desktop warnings. Use the [first-boot checks](docs/INSTALL.md#11-first-boot-verification)
to test notifications and EFI free space. Normal + full TIF is now the DNS
default; measure its memory during a daily refresh using
[the DNS guide](docs/NETWORKING.md) before deciding whether to reduce coverage.

Open a new Zsh after the first activation. These aliases distinguish evaluation
from activation:

```bash
nix-check       # evaluate checks, build nothing
nix-dry         # build, do not activate
nix-test        # activate until reboot, do not change boot default
systemctl --failed
nix-switch      # activate now and set the boot default
```

Run the security-hook integration tests separately:

```bash
nix build .#checks.x86_64-linux.git-security --no-link --print-build-logs
```

Use `checks.aarch64-darwin.git-security` on an Apple Silicon development host.
CI additionally scans history for credentials and the current tree for PII;
it cannot prevent an initial upload, so keep local hooks enabled.

Use `nix-show`, `nix-metadata`, `nix-update`, `nix-boot`, `nix-generations`,
`nix-search`, and `nix-why` for the corresponding inspection/update workflows.
The full alias table and Secure Boot procedure remain in
[docs/INSTALL.md](docs/INSTALL.md).
