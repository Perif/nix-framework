# Installation guide

This is a clean UEFI installation for the Framework Laptop described by this
repository. The Disko step erases the entire drive selected in `settings.nix`.
Read the guide once before running commands, keep a backup of all required data,
and do not continue if the disk identity is uncertain.

The guide follows the NixOS manual installation flow and uses the Disko revision
already pinned in `flake.lock`.

For an existing installation, skip the destructive installation steps. Read
[the one-time model-storage migration](#one-time-model-storage-migration-for-an-existing-installation)
before activating this revision: the new subvolume must exist first.

## Values you must review

All installation-specific configuration is in `settings.nix`:

| Setting | Required action |
| --- | --- |
| `hostname` | Keep `framework-pro` or choose the final hostname. |
| `timeZone` | Starts as `null`; run the install-time detection command below to save an IANA zone, or select one explicitly. The saved zone remains fixed after installation. |
| `defaultLocale` | Keep or replace `en_US.UTF-8`. |
| `consoleKeyMap` | Keep or replace `us`. |
| `dns.*` | Keep or consistently replace the unfiltered encrypted upstream and bootstrap addresses. Review the Blocky switch, privacy list, and allowlist using `docs/NETWORKING.md`. |
| `diskDevice` | **Required:** replace the rejected sentinel with the verified NVMe `/dev/disk/by-id/...` path. |
| `user.name` | Set the local login name. |
| `user.description` | Set the displayed full name. |
| Both password fields | Prefer leaving both `null`; set the password after `nixos-install` in step 9. |
| `user.sshAuthorizedKeys` | Optional. Add only complete public keys you control. An empty list keeps sshd disabled. |
| `features.qbz` | Keep `false`: upstream distribution is closed. Enabling requires a separately maintained `qbz.packageFile`; see README. |
| `features.secureBoot` | Keep `false` for installation. Enable only after creating and verifying local keys in step 13. |
| Git name and email | Replace the example identity. |

You will also choose a LUKS passphrase interactively during disk formatting. It
is separate from the login password created after installation.

## 1. Boot the installer in UEFI mode

Create an installer USB from the current NixOS stable ISO and boot its UEFI
entry. The configuration includes a staged signed-boot path, but
`features.secureBoot` must remain `false` and firmware Secure Boot must remain
disabled for the initial installation.

Open a terminal and become root:

```bash
sudo -i
```

Confirm that the installer itself was booted in UEFI mode:

```bash
if test -d /sys/firmware/efi/efivars; then
  echo "UEFI mode detected"
else
  echo "Not booted in UEFI mode; stop and reboot the installer"
fi
```

Optionally select a different console keyboard before entering passwords:

```bash
loadkeys us
```

## 2. Connect to the network

For Wi-Fi, use NetworkManager's text interface:

```bash
nmtui
```

Verify connectivity and clock synchronization:

```bash
curl --fail --head https://cache.nixos.org/
timedatectl status
```

Enable the Nix CLI features used by this flake for the installer shell:

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
nix --version
```

## 3. Put the configuration in `/tmp`

Clone your repository if it has a remote:

```bash
REPOSITORY_URL="REPLACE_WITH_YOUR_REPOSITORY_URL"
git clone "$REPOSITORY_URL" /tmp/nixos-config
cd /tmp/nixos-config
```

If the files are on another USB drive, copy the repository directory to
`/tmp/nixos-config` instead, then enter it:

```bash
CONFIG_SOURCE="/run/media/nixos/REPLACE_WITH_THE_CONFIG_DIRECTORY"
cp -a "$CONFIG_SOURCE" /tmp/nixos-config
cd /tmp/nixos-config
```

Confirm that the pinned inputs are present:

```bash
test -f flake.nix
test -f flake.lock
```

Do not run `nix flake update` during installation. The existing lock file is the
reviewed, reproducible dependency set.

## 4. Identify the target NVMe drive

First confirm the machine and list whole drives:

```bash
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/product_version
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN
```

List stable NVMe identifiers, excluding partition links:

```bash
ls -l /dev/disk/by-id/nvme-* | grep -v -- '-part'
```

For this build, the intended drive is the **Samsung SSD 990 EVO Plus 2TB**
(model family `MZ-V9S2T0`). Its 2,000 GB decimal capacity normally appears as
about 1.82 TiB in tools that use binary units. Samsung does not advertise WWN
support for this model, so an `nvme-eui.*` link may not exist. Use the exact
model-and-serial `/dev/disk/by-id/` link that the command above prints.

Set a temporary shell variable. Replace the example; do not paste it unchanged:

```bash
INSTALL_DISK="/dev/disk/by-id/REPLACE_WITH_THE_EXACT_NVME_LINK"
```

Require it to resolve to a block device and inspect it again:

```bash
test -b "$INSTALL_DISK"
readlink -f "$INSTALL_DISK"
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS "$INSTALL_DISK"
wipefs --no-act "$INSTALL_DISK"
```

Stop if the size, model, serial, resolved device, or existing signatures do not
match the drive you intend to erase.

## 5. Update `settings.nix`

Edit the file:

```bash
nano settings.nix
```

The following excerpt shows installation-specific fields to edit in place.
Do not replace the whole file: retain the existing `power`, `builds`, `storage`,
`network`, `ai`, `display`, `audio`, `qbz` and additional `features` settings. Replace every value
marked for replacement and use the exact `INSTALL_DISK` value verified above:

```nix
{
  hostname = "framework-pro";

  timeZone = null; # Filled by the detection command below; or set an explicit IANA zone.
  defaultLocale = "en_US.UTF-8";
  consoleKeyMap = "us";

  # Unfiltered Blocky upstream and direct Firefox recovery endpoint.
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

    # Recommended installation path: set the password in step 9.
    hashedPassword = null;
    initialPassword = null;

    # Leave empty unless remote SSH access is required.
    sshAuthorizedKeys = [ ];
  };

  features = {
    qbz = false;

    # Enable only after completing the post-install Secure Boot procedure.
    secureBoot = false;
  };

  git = {
    userName = "REPLACE WITH YOUR GIT NAME";
    userEmail = "REPLACE_WITH_YOUR_EMAIL@example.com";
  };
}
```

To enable key-only SSH, use your complete public key; never place a private key
in this repository:

```nix
sshAuthorizedKeys = [
  "ssh-ed25519 AAAAC3... workstation"
];
```

### Detect the installation timezone

Before proceeding to evaluation or disk partitioning, run:

```bash
nix run .#detect-timezone
nix eval --raw --impure --expr '(import ./settings.nix).timeZone'
```

The helper makes one HTTPS request to [ipapi.co](https://ipapi.co/api/) using the
installer's public IP, validates the returned IANA zone against the pinned
timezone database, and writes it into `settings.nix`. It does not change the
live installer's clock or send Wi-Fi scan/GPS data. Review the printed zone:
a VPN/proxy or incorrect IP geolocation may return a different region.

An explicit zone is preserved without a network lookup. To bypass detection,
correct a result, or recover from an unavailable/rate-limited service, use:

```bash
nix run .#detect-timezone -- --timezone Europe/Paris
```

You can also set `timeZone` directly. A failed lookup leaves the file unchanged;
`null` blocks system evaluation rather than silently selecting Chicago or UTC.
No location service is enabled on the installed laptop. After travel, change
this saved value and rebuild as described in the first-boot checks.

List available regional values when needed:

```bash
timedatectl list-timezones
locale -a
localectl list-keymaps
```

### Optional declarative password

The preferred path is to leave both password settings `null` and use step 9.
If a declarative password is required, generate a yescrypt hash:

```bash
nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt
```

Place the complete result in `hashedPassword` and keep `initialPassword = null`.
The plaintext is not stored, but the hash is still copied into Git history and
the world-readable Nix store, so use a strong unique password and do not publish
the repository.

## 6. Evaluate before touching the disk

Read the configured hostname and username directly from `settings.nix`:

```bash
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
INSTALL_USER="$(nix eval --raw --impure --expr '(import ./settings.nix).user.name')"
printf 'Host: %s\nUser: %s\nDisk: %s\n' "$INSTALL_HOST" "$INSTALL_USER" "$INSTALL_DISK"
```

Confirm that the shell variable and declarative disk value are identical:

```bash
CONFIGURED_DISK="$(nix eval --raw --impure --expr '(import ./settings.nix).diskDevice')"
printf 'Shell disk:  %s\nConfig disk: %s\n' "$INSTALL_DISK" "$CONFIGURED_DISK"
test "$INSTALL_DISK" = "$CONFIGURED_DISK"
```

Evaluate every flake output without building the complete system:

```bash
nix flake check --no-build --all-systems
nix eval --raw ".#nixosConfigurations.${INSTALL_HOST}.config.system.build.toplevel.drvPath"
```

Warnings are not failures; any final `error:` must be resolved before proceeding.

Ask Disko to resolve the operation without executing it. Its `--dry-run` prints
the generated script path; it is an evaluation check, not a visual partition
preview:

```bash
nix run .#disko -- \
  --dry-run \
  --mode destroy,format,mount \
  --flake ".#${INSTALL_HOST}"
```

## 7. Erase, encrypt, format, and mount the drive

**Everything currently on `INSTALL_DISK` will be destroyed.** Repeat the
identity checks immediately before the destructive command:

```bash
test -b "$INSTALL_DISK"
readlink -f "$INSTALL_DISK"
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS "$INSTALL_DISK"
```

Run the pinned Disko package:

```bash
nix run .#disko -- \
  --mode destroy,format,mount \
  --flake ".#${INSTALL_HOST}"
```

Enter a strong, unique LUKS passphrase when prompted. Keep a recovery copy in a
password manager or another secure location.

Verify the generated mounts and encrypted swap:

```bash
findmnt --real --submounts /mnt
swapon --show
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

Expected mount points include `/mnt`, `/mnt/boot`, `/mnt/home`, `/mnt/nix`,
`/mnt/var/log`, `/mnt/.snapshots`, and `/mnt/var/lib/private/ollama`.
The active physical swap should be about
40 GiB and should be inside the encrypted LVM layout.

### SSD discard privacy boundary

The configuration permits TRIM through LUKS and enables swap discard. This is a
practical SSD performance/wear choice, but it can reveal which encrypted blocks
are unused. For a maximum-confidentiality posture, set `allowDiscards = false`
and remove `discardPolicy = "both"` in `hosts/framework-pro/disk.nix` before the
Disko step. That choice may reduce SSD space-reclamation effectiveness.

## 8. Copy the reviewed configuration and install NixOS

Copy the exact evaluated configuration onto the new system:

```bash
install -d -m 0755 /mnt/etc/nixos
cp -a /tmp/nixos-config/. /mnt/etc/nixos/
chown -R root:root /mnt/etc/nixos
chmod -R go-w /mnt/etc/nixos
test -f /mnt/etc/nixos/flake.lock
```

Do not run `nixos-generate-config` over this repository. Disko already declares
the filesystems, swap, and resume device, while the pinned `nixos-hardware`
module and NixOS defaults provide the Framework and initrd hardware settings.
Adding generated filesystem declarations would create conflicting ownership.

Install without creating an enabled root password:

```bash
nixos-install \
  --flake "/mnt/etc/nixos#${INSTALL_HOST}" \
  --no-root-passwd
```

Keep the 40 GiB swap active during installation. QBZ is disabled by default
because its upstream source is unavailable; first boot does not require it.

Do **not** rerun the destructive Disko step merely because `nixos-install`
failed. Correct the configuration or network problem and rerun the installation.

## 9. Set the login password before rebooting

When both password fields are `null`, the account is initially locked. Set its
password inside the installed system so no password material enters the flake:

```bash
nixos-enter --root /mnt -c "passwd ${INSTALL_USER}"
nixos-enter --root /mnt -c "passwd --status ${INSTALL_USER}"
```

The status line should report `P` for a usable password, not `L` for locked.
Skip this step only if you intentionally supplied `hashedPassword` earlier.

Confirm that the user and installed system generation exist:

```bash
nixos-enter --root /mnt -c "id ${INSTALL_USER}"
readlink -f /mnt/nix/var/nix/profiles/system
ls -l /mnt/boot/loader/entries/
```

## 10. Reboot

Flush pending writes, reboot, and remove the installer USB when firmware starts:

```bash
sync
reboot
```

At cold boot, enter the LUKS passphrase and then log in at SDDM with the user
password from step 9.

## 11. First-boot verification

Enter the installed configuration and resolve the hostname again:

```bash
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
```

Check failed services, mounts, swap, boot mode, and graphics:

```bash
systemctl --failed
for mountpoint in / /home /nix /var/log /.snapshots /boot /var/lib/private/ollama; do
  findmnt --mountpoint "$mountpoint"
done
swapon --show
bootctl status
vulkaninfo --summary
vainfo
clinfo --list
```

Verify the system time, configured zone, daylight-saving state, and network
clock synchronization used by Plasma:

```bash
timedatectl status
timedatectl timesync-status
systemctl is-active systemd-timesyncd.service
```

The service must be active, `System clock synchronized` should become `yes`
after networking is available, and `Time zone` must match `settings.timeZone`.
Plasma's digital clock uses this system zone by default; if an existing panel
widget was previously pinned to another zone, open **Configure Digital Clock**,
select **Time Zones**, then select **Local**.

GeoClue is intentionally disabled, so the system cannot infer a new time zone
when travelling. Update the one installation setting instead:

```nix
# /etc/nixos/settings.nix
timeZone = "Europe/Paris";
```

Apply it and recheck the result:

```bash
sudo nixos-rebuild switch --flake ".#${INSTALL_HOST}"
timedatectl status
```

This changes the displayed local time and daylight-saving rules without
changing the synchronized clock or sending location requests. Automatic
weather location and location-based Night Color are unavailable; configure a
city manually in the weather widget and use fixed Night Color times if needed.

Verify adaptive Intel thermal management, the selectable power profiles,
compressed-memory tuning, and background Nix scheduling:

```bash
systemctl is-active thermald.service
journalctl -b -u thermald.service --no-pager
powerprofilesctl list
powerprofilesctl get
sysctl vm.swappiness vm.page-cluster
zramctl
swapon --show
systemctl show nix-daemon.service \
  -p CPUSchedulingPolicy \
  -p IOSchedulingClass \
  -p IOSchedulingPriority
nix config show max-jobs
nix config show cores
nix config show allowed-users
nix config show trusted-users
```

The expected performance values and safe use of the temporary performance
profile are documented in `docs/PERFORMANCE.md`. Do not force thermald past a
CPU-identification or adaptive-table error.

`allowed-users` must contain only `root` and the username configured under
`settings.user.name`; `trusted-users` must contain only `root`. This confirms
that changing the installation username updates Nix-daemon access without
granting the entire `wheel` group trusted Nix privileges.

Confirm the IPv6 host hardening without disabling normal address assignment or
router advertisements:

```bash
sysctl \
  net.ipv6.conf.all.accept_redirects \
  net.ipv6.conf.default.accept_redirects \
  net.ipv6.conf.all.accept_source_route \
  net.ipv6.conf.default.accept_source_route
```

The redirect values must both be `0`; the source-route values must both be
`-1`.

Check the firewall, scheduled storage maintenance, snapshot policy, and
low-priority Nix store optimization:

```bash
systemctl is-active firewall.service
systemctl list-timers --all \
  'btrfs-scrub-*' \
  snapper-timeline.timer \
  snapper-cleanup.timer \
  nix-optimise.timer
sudo snapper -c root list
sudo btrfs scrub status /
```

Confirm that system DNS is using loopback Blocky, that no fallback resolver was
injected, and that ordinary resolution works:

```bash
systemctl is-active blocky.service
systemctl show blocky.service -p ActiveState -p SubState
resolvectl status
resolvectl query example.com
ss -lntup | grep ':5335'
readlink -f /etc/resolv.conf
```

Blocky should be active with only `127.0.0.1:5335` and `[::1]:5335` listeners.
`resolvectl status` should show those local addresses as the global DNS servers,
and `/etc/resolv.conf` should resolve to the systemd-resolved stub. The local hop
is plain DNS on loopback; Blocky sends allowed queries to the configured
unfiltered provider through DoH on HTTPS port 443. Firefox uses that provider
directly as the documented unfiltered recovery browser. See
`docs/NETWORKING.md` before changing DNS, allowlisting a domain, or importing a
VPN profile with private DNS.

Inspect the active randomized MAC address and the defaults applied to new
NetworkManager profiles:

```bash
nmcli -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.HWADDR device show
nmcli connection show
nmcli connection show "REPLACE_WITH_AN_ACTIVE_CONNECTION" | \
  grep -E 'cloned-mac-address|dhcp-send-hostname'
```

Wi-Fi uses a different stable randomized address for each SSID; Ethernet uses
a stable randomized address for each connection profile. The address remains
stable on reconnect so DHCP leases and captive portals continue to work.
`docs/SECURITY-PRIVACY.md` documents the per-network override for a network
that requires the hardware address.

Confirm that the configuration still evaluates before the first routine switch:

```bash
sudo nixos-rebuild dry-build --flake ".#${INSTALL_HOST}"
```

Check firmware updates and record an initial NVMe health report. The SMART
service should already be monitoring the drive and will write failures to the
journal, notify logged-in terminals, and record a persistent warning for the
configured user's Plasma session:

```bash
fwupdmgr get-devices
fwupdmgr get-updates
systemctl is-active smartd.service
sudo smartctl --scan-open
SYSTEM_DISK="$(nix eval --raw --impure --expr '(import ./settings.nix).diskDevice')"
sudo smartctl -x "$SYSTEM_DISK"
```

The report should identify the Samsung 990 EVO Plus and show an overall passed
health assessment with no critical warning or media/data-integrity error. A
warning is a reason to verify the backup and investigate immediately, not a
replacement for an off-device backup.

Test the desktop notification while logged in to Plasma. First inspect the
journal: if an alert marker already exists, treat it as a real warning rather
than clearing it as a test.

```bash
sudo journalctl -u smartd.service --since today
sudo test ! -e /var/lib/disk-health/alert
# Continue only if the preceding test succeeds and no real fault is pending.
sudo touch /var/lib/disk-health/alert
systemctl --user start disk-health-alert.service
systemctl --user status disk-health-alert.path disk-health-alert.timer
```

Expect a critical **Disk health needs attention** notification. The marker is
root-owned; no system-wide writable notification bus is exposed. Warnings
also appear after login and repeat hourly while the marker exists. After
confirming this is only your test (or resolving a real fault), acknowledge it:

```bash
sudo rm -- /var/lib/disk-health/alert
```

This removes only the notification marker, not SMART history or journal data.
It cannot restore a failing drive. New SMART events recreate the marker.
This tests the marker-to-desktop path; an actual smartd event still needs to
be verified on Linux. Do not simulate a disk failure or run destructive tests.

Both boot modes retain at most three generations on the 1 GiB EFI partition.
Check space before and after kernel updates; the limit is not a byte quota:

```bash
df -h /boot
bootctl list
```

Keep space for at least one additional kernel/initrd or signed-image set during
an update. If three generations do not leave that margin, lower both limits
in `modules/nixos/secure-boot.nix`; do not delete EFI files manually.

Enroll and verify the fingerprint reader:

```bash
fprintd-enroll
fprintd-verify
```

Verify the declarative session-lock and authentication boundaries. First lock
the current Plasma session and unlock it with the enrolled fingerprint:

```bash
loginctl lock-session
```

Then invalidate any cached sudo credential and confirm that sudo asks for the
account password rather than offering fingerprint authentication:

```bash
sudo -k
sudo -v
```

Leave the desktop idle for at least five minutes and confirm that it locks.
Save all work, suspend once, and confirm that the lock screen appears
immediately on resume. The settings are Nix-owned in
`home/modules/plasma-security.nix`; change them there rather than in Plasma
System Settings.

Save all work, then test hibernation before testing the combined sleep path:

```bash
systemctl hibernate
systemctl suspend-then-hibernate
```

Do not enable TPM2 auto-unlock until cold boot, hibernation, resume, and password
recovery have all been tested. Continue with `docs/FINGERPRINT-TPM.md` afterward.

Select the matching panel ICC using [display setup](DISPLAY.md), then follow
[EasyEffects speaker setup](AUDIO.md#easyeffects-speaker-preset) to associate
the bundled preset with the built-in speaker device and route. Verify that
switching to headphones selects the Flat fallback. These profiles are
installed declaratively; the panel and audio-route identities need checking
on this laptop before use.

For the DC-Elite audio path:

```bash
aplay -l
dc-elite-alsa-config
```

Follow `docs/AUDIO.md` before writing the generated ALSA configuration.

Strawberry, qobuz-player and MusicBrainz Picard are installed for the login user.
Use Strawberry for local playback, follow the [qobuz-player setup](AUDIO.md#qobuz-player--qobine)
for streaming and explicit DC-Elite device selection, and use Picard for tagging.
Only one direct-ALSA player can use the DAC at a time.

Keep QBZ disabled unless you have supplied an independently maintained Nix
package through `qbz.packageFile`. The upstream project and distribution
channels have closed; the optional integration is documented in the README.

Open Firefox and verify `about:policies`, `about:addons`, and
`about:preferences#privacy`. The uBlock Origin advanced controls are enabled,
but its per-site dynamic rules remain user-owned; follow `docs/FIREFOX.md` to
activate medium mode if that stricter uMatrix-like behavior is wanted.

Follow [workstation application setup](WORKSTATION-APPS.md) for Wine, KeePassXC
and 1Password import, direnv, NH, mpv, and Open WebUI's first admin account.
Check [build tuning](PERFORMANCE.md#measuring-build-and-inference-contention)
before selecting `builds.maxJobs` and `builds.cores` for this laptop.

Confirm that VSCodium, both local model runtimes, and the Nix/Python/Go/Rust
toolchain are installed. Ollama should initially report `inactive` because it
is an on-demand service rather than a boot service:

```bash
command -v codium
command -v ollama
command -v llama-server
command -v nixd
command -v nixfmt
command -v basedpyright
command -v ruff
command -v go
command -v gopls
command -v dlv
command -v golangci-lint
command -v rustc
command -v cargo
command -v rust-analyzer
codium --list-extensions
systemctl show ollama.service -p ActiveState
```

The extension list should contain twelve immutable extensions: Continue; Nix
IDE; Python, Debugpy, BasedPyright, and Ruff; Go; rust-analyzer and CodeLLDB;
YAML; TOML; and EditorConfig. The complete IDs and language-level checks are in
`docs/LOCAL-AI-DEVELOPMENT.md`.

Start it explicitly, verify the loopback-only endpoint, and stop it again:

```bash
sudo systemctl start ollama.service
systemctl is-active ollama.service
curl --fail http://127.0.0.1:11434/api/tags
sudo systemctl stop ollama.service
systemctl show ollama.service -p ActiveState
```

The checks before the start and after the stop should both report
`ActiveState=inactive`; the middle check should report `active`. The configured
Zsh aliases are `ollama-on`, `ollama-off`, and `ollama-status`. No model is
downloaded automatically. Follow
`docs/LOCAL-AI-DEVELOPMENT.md` to choose a tool-capable Ollama model or serve a
GGUF model with llama.cpp, then select it in Continue.

Confirm that Brave and ungoogled Chromium are installed:

```bash
command -v brave
command -v chromium
chromium --version
readlink -f "$(command -v chromium)"
```

The resolved Chromium path should contain `ungoogled-chromium`. The executable
remains named `chromium`.

Open `brave://policy` and `chrome://policy`, reload policy, and verify the
managed privacy controls. Check `brave://extensions` for uBlock Origin Lite.
Open `chrome://extensions` and confirm that ungoogled Chromium has no unexpected
extension; uBOL is intentionally limited to Brave because its automatic update
path uses the Chrome Web Store. The managed-browser message is expected because
the policies come from this NixOS configuration. See
`docs/CHROMIUM-BROWSERS.md` for the exact controls, Safe Browsing boundary, and
compatibility procedure.

Confirm that Tor Browser and WireGuard's client tools are installed:

```bash
command -v tor-browser
command -v wg
command -v wg-quick
```

Confirm that the Git credential/PII checks and global pre-commit hook are
installed:

```bash
command -v gitleaks
command -v git-staged-pii-scan
git-staged-pii-scan --self-test
git config --global --show-origin --get core.hooksPath
git config --global --get hooks.gitleaks
git config --global --get hooks.piiCheck
```

The last two commands should both print `true`. See `docs/GIT-SAFETY.md` for a
manual staged scan, false-positive handling, and the limits of client-side
hooks.

Launch Tor Browser from Plasma or run `tor-browser`, complete its connection
screen, and verify it at `https://check.torproject.org/`. Do not add extensions
or copy the hardened Firefox profile into Tor Browser; see
`docs/TOR-BROWSER.md`.

For a UniFi WireGuard client profile, follow `docs/NETWORKING.md`. The profile
contains a private key, so never paste it into `settings.nix`, commit it, or
store it in the Nix store.

## 12. Customize DNS, shells, and editors

All managed preferences are read-only Nix store links after activation. Edit
the source under `/etc/nixos`, test a generation, then switch it permanently;
do not edit the generated files under `$HOME/.config`.

### Blocky exceptions and emergency bypass

Blocky is enabled by default with HaGeZi Normal plus full TIF. If a site works
in Firefox but not in ungoogled Chromium or a system application, add a narrow
exception in `/etc/nixos/settings.nix`; the exception takes precedence over
both lists:

```nix
dns.filtering.allowlist = [
  "example.com"
  "*.example.com"
];
```

Apply it as a temporary generation and clear cached negative answers:

```bash
cd /etc/nixos
nix-check
nix-test
sudo systemctl restart blocky.service
resolvectl flush-caches
resolvectl query example.com
```

Use `nix-switch` only after the test succeeds. For diagnosis, set
`dns.filtering.enable = false` and run `nix-test`; this bypasses Blocky but keeps
the unfiltered provider and strict encrypted system DNS. Restore `true` after
identifying the cause. `docs/NETWORKING.md` covers UniFi split DNS and captive
portals.

### Zsh Nix aliases

Start a new shell after rebuilding, then inspect the managed aliases:

```bash
alias | grep '^nix-'
```

The workflow is intentionally explicit:

| Alias | Behavior |
| --- | --- |
| `nix-check` / `ncheck` | Evaluate flake checks without building outputs. |
| `nix-show` | Show flake outputs. |
| `nix-metadata` | Show pinned input revisions. |
| `nix-update` | Update `/etc/nixos/flake.lock`; review the change before activation. |
| `nix-dry` | Build the system closure without activating it. |
| `nix-test` | Activate temporarily; the boot default is unchanged. |
| `nix-boot` | Make the generation the next boot target without changing the running system. |
| `nix-switch` / `rebuild` | Build, activate now, and make the generation the boot default. |
| `nix-generations` | List system generations. |
| `nix-search SEARCH_TERM` | Search the pinned registry package set. |
| `nix-why STORE_PATH` | Explain why a path is in the current system closure. |

Do not alias garbage collection: deletion of generations and store paths should
remain a deliberate, fully typed operation.

### VSCodium and local agents

VSCodium's extension directory is immutable. Add or remove extensions only in
`home/modules/vscodium.nix`; do not use `codium --install-extension`. Continue
is the single agent extension and connects only to the loopback Ollama and
llama.cpp endpoints. The rest of the pinned extension list covers Nix, Python,
Go, Rust, YAML, TOML, EditorConfig, and local debugging.

Repository formatting should be declared in `.editorconfig` rather than by
changing the global profile for one project. For example:

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.nix]
indent_style = space
indent_size = 2

[*.py]
indent_style = space
indent_size = 4
```

Generated `.direnv`, `.venv`, `node_modules`, `result`, and `target` trees are
excluded from editor watching/search for responsiveness. Remove an exclusion in
`home/modules/vscodium.nix` only when a project genuinely needs to search that
tree. Local model names and context limits are changed in the same module; see
`docs/LOCAL-AI-DEVELOPMENT.md` for the exact YAML snippet and resource limits.

### Vim and Neovim

`home/modules/vim.nix` shares the same settings and pinned EditorConfig plug-in
between Vim and Neovim. Vim remains `$EDITOR`; Neovim remains available as
`nvim`. Both disable modelines, use separate persistent undo directories under
`~/.local/state/vim/` and `~/.local/state/nvim/`, keep swap/backup data out of
project directories, and provide search, split, completion, and Wayland
clipboard defaults.

Verify the commands and clipboard helper:

```bash
command -v vim
command -v nvim
command -v wl-copy
vim --version | head -n 3
nvim --version | head -n 3
```

Change shared behavior once in the `commonConfig` block. Project indentation
should stay in `.editorconfig`; the four-space global fallback is for files
without project policy.

### Sublime Text packages and language servers

The editor is pinned to stable build 4213 (21 September 2026) in
`home/modules/sublime.nix`, using verified download hashes for x86-64 and ARM64
Linux. This is a targeted package update; `flake.lock` is unchanged. Rebuild
normally, fully quit Sublime, reopen it, and check:

```bash
subl --version
```

Expect build 4213. The managed setting `"disable_plugin_host_3.3": true`
keeps plugins on Python 3.14. Legacy Python 3.3 and bundled OpenSSL 1.1 are
removed, with build-time dependency checks on the surviving binaries. Do not
enable the legacy host to work around an incompatible plugin. Retest Package
Control, EditorConfig and each LSP server below; Nix evaluation is not a GUI
or plugin-runtime test. Release details: [official changelog](https://www.sublimetext.com/download).

On the first launch only, select **Tools > Install Package Control**, then
restart Sublime Text. The Nix-owned Package Control settings install only:

```text
EditorConfig
LSP
Nix
Package Control
```

Package Control usage reporting and prereleases are disabled, its official
channel is the only configured channel, and updates are checked once per day.
The Nix package is syntax-only. BasedPyright, Ruff, gopls, rust-analyzer, and
nixd are not downloaded by Sublime plug-ins: the LSP configuration points to
their pinned Nix store binaries.

On Linux, open **View > Show Console** after restarting and check for plugin
host crashes, missing-library errors, and failed package imports. Verify
EditorConfig changes indentation in a test project and each language server
starts. Plugins selecting the removed Python 3.3 host must be upgraded or
replaced; do not reintroduce OpenSSL 1.1 to make them load. This runtime check
is required even after a successful build. For tighter supply-chain control,
review and pin plugin archives in Nix with an explicit update process; this
build currently retains Package Control's independently updated packages.

Package Control packages are not rolled back with a Nix generation. The small
installation list is not an enforced allowlist: other packages can still be
installed manually, and updates are not individually reviewed by Nix. Daily
updates reduce exposure to stale plug-ins, but this remains
less reproducible than VSCodium's immutable extension set. Review a newly
requested Sublime package before adding it to `installed_packages`; never add a
private repository or alternate package channel merely for convenience.

Open one `.py`, `.go`, `.rs`, and `.nix` file inside a project folder. The LSP
status indicator should show the corresponding server. Use **Tools > LSP >
Troubleshoot Server** if one does not start. Settings and server commands live
in `home/modules/sublime.nix`; the Python 3.3 plug-in host remains removed and
must not be restored to accommodate an obsolete package.

After any customization, use the same promotion sequence:

```bash
cd /etc/nixos
nix-check
nix-test
systemctl --failed
nix-switch
```

## 13. Enable signed Secure Boot

Complete this only after normal boot, hibernation, recovery-passphrase boot,
firmware updates, and the previous verification steps all work. Keep the NixOS
installer USB available. If signed boot fails, disable Secure Boot enforcement
in firmware and boot the previous working configuration.

Confirm firmware state and create machine-local keys:

```bash
sudo sbctl status
sudo sbctl create-keys
sudo ls -la /var/lib/sbctl
```

The private keys under `/var/lib/sbctl` must never be copied into this
repository or the Nix store. Back them up only to encrypted offline storage.

In `/etc/nixos/settings.nix`, change only `secureBoot` inside the existing
`features` block; preserve the QBZ and Thunderbolt choices:

```nix
secureBoot = true;
```

Evaluate, install the signed Lanzaboote generation, and verify the EFI images
before changing firmware key state:

```bash
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild dry-build --flake ".#${INSTALL_HOST}"
sudo nixos-rebuild switch --flake ".#${INSTALL_HOST}"
sudo sbctl verify
```

The Lanzaboote verification output may list old raw `kernel-*` files as
unsigned; the EFI boot entries and unified NixOS generation images must be
signed.

Reboot into the Framework firmware and enter Secure Boot Setup Mode. Under
**Administer Secure Boot**, delete the individual entries under PK, KEK, and DB
as described by Lanzaboote. Do **not** select **Erase all Secure Boot Settings**;
Lanzaboote documents that option as unsafe on affected Framework firmware.
Boot back into NixOS, then retain both Microsoft and firmware-provisioned keys
when enrolling:

```bash
sudo sbctl enroll-keys --microsoft --firmware-builtin
sudo sbctl status
sudo sbctl verify
```

Reboot into firmware again, enable **Enforce Secure Boot**, boot NixOS, and
verify the final state:

```bash
bootctl status
sudo sbctl status
sudo sbctl verify
```

`bootctl status` must report Secure Boot enabled in user mode. Keep
`features.secureBoot = true` for future rebuilds. Only after this is stable
should TPM2 auto-unlock be considered; see `docs/FINGERPRINT-TPM.md`. Confirm
that the firmware forbidden-signature database (`dbx`) is present and current,
then set a strong firmware administrator password so an unattended person
cannot simply change the Secure Boot policy. Store that password with the LUKS
recovery credential; losing it can make firmware recovery difficult.

Reboot into firmware one final time and verify that changing Secure Boot state
or key-management settings requires the new administrator password. Boot NixOS
again and repeat the three status checks above. Do not consider the Secure Boot
procedure complete until both the password gate and signed-boot verification
have passed.

## 14. Routine safe rebuild workflow

### Xbox Elite Series 2 controller

USB-C uses the kernel Xbox driver; Bluetooth uses the pinned xpadneo module.
Bluetooth remains powered off at boot. Enable it in Plasma and follow
[CONTROLLERS.md](CONTROLLERS.md) for pairing, button/rumble checks, profile
limitations, and troubleshooting. The proprietary Xbox Wireless USB adapter
is not enabled. No blanket input-group access or Bluetooth security downgrade
is required.

### One-time model-storage migration for an existing installation

Skip this subsection for a fresh Disko installation: it already creates the
dedicated `/ollama` Btrfs subvolume mounted at `/var/lib/private/ollama`.
Systemd keeps `/var/lib/ollama` as its service-facing symlink. The private
ancestor is mode 0700 and Ollama retains DynamicUser and its existing sandbox.
Model downloads and deletions no longer accumulate in root snapshots.

If upgrading the older layout, create and populate the subvolume **before any
activation or reboot into this configuration**. Never rerun Disko. Back up any
irreplaceable models first. Confirm `/dev/mapper/vg-root` is the Btrfs root LV
from this configuration; stop if your actual layout differs:

```bash
findmnt /
sudo lvs -o lv_path,vg_name,lv_name
sudo blkid /dev/mapper/vg-root
sudo systemctl stop ollama.service
sudo systemctl mask --runtime ollama.service
MODEL_TOP="$(mktemp -d /tmp/ollama-subvolume.XXXXXX)"
sudo mount -o subvolid=5 /dev/mapper/vg-root "$MODEL_TOP"
sudo test ! -e "$MODEL_TOP/ollama"
```

Continue only if that last check succeeds. If `/ollama` already exists, inspect
its contents and mount state; do not overwrite it or repeat the copy blindly.

```bash
(
set -eu
sudo btrfs subvolume create "$MODEL_TOP/ollama"
if sudo test -d /var/lib/private/ollama; then
  sudo cp -a --reflink=auto /var/lib/private/ollama/. "$MODEL_TOP/ollama/"
  sudo diff -qr /var/lib/private/ollama "$MODEL_TOP/ollama"
fi
sudo btrfs filesystem sync "$MODEL_TOP"
sudo umount "$MODEL_TOP"
rmdir "$MODEL_TOP"
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild boot --flake ".#${INSTALL_HOST}"
sudo reboot
)
```

Stop on a failed copy, comparison, unmount, or rebuild; do not continue to reboot.
After reboot, verify the new mount and then explicitly start Ollama:

```bash
findmnt /var/lib/private/ollama
sudo stat -c '%a %U %G' /var/lib/private
sudo systemctl start ollama.service
sudo readlink -f /var/lib/ollama
ollama list
```

The mount should report `subvol=/ollama`, the private ancestor should be
`700 root root`, and the model list should be unchanged. The old root-resident
copy is intentionally retained underneath the mount for recovery; existing
snapshots may also retain it. It is not automatically erased. After verifying
the new store and a backup, plan cleanup of the old copy from a top-level Btrfs
mount; keep its path distinct from the active `/ollama` subvolume. Future root
snapshots exclude the new store, including Ollama's service identity files.

### Normal rebuilds

After changing configuration, evaluate first, activate temporarily, and switch
only after basic checks pass:

```bash
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
nix flake check --no-build --all-systems
sudo nixos-rebuild test --flake ".#${INSTALL_HOST}"
systemctl --failed
sudo nixos-rebuild switch --flake ".#${INSTALL_HOST}"
```

Use the previous generation from the systemd-boot menu if a new generation
cannot boot. Do not rerun Disko for routine rebuilds or upgrades.

## CI verification

Run the packaged production-hook integration tests locally (this builds and
runs tests, unlike `nix flake check --no-build`):

```bash
# On the NixOS laptop:
nix build .#checks.x86_64-linux.git-security --no-link --print-build-logs
# On an Apple Silicon development host:
nix build .#checks.aarch64-darwin.git-security --no-link --print-build-logs
```

The tests use disposable repositories and synthetic data. They cover staged
credentials/PII, redacted diagnostics, unusual filenames, staged versus
unstaged changes, reviewed exclusions, Git errors, and chained local hooks.
CI also scans fetched Git history with Gitleaks and scans a disposable staged
copy of the current committed tree with the PII scanner. High-confidence PII
blocks; lower-confidence findings remain review warnings. Binary content and
all forms of PII are not covered. CI runs after upload, so local hooks remain
the pre-upload protection. No workflow success is implied until it runs on
your repository host.

`.github/workflows/nix.yml` evaluates every flake output and builds the default
x86_64-linux system on an Ubuntu runner for pull requests and pushes to `main`.
The workflow substitutes only a non-device CI disk identifier, never
runs Disko, and pins its GitHub Actions by commit. A green workflow is the full
Linux build check that an ARM macOS development host cannot perform locally.

## References

- [NixOS manual installation](https://nixos.org/manual/nixos/stable/)
- [Disko command reference](https://github.com/nix-community/disko/blob/master/docs/reference.md)
- [Lanzaboote: prepare the system](https://github.com/nix-community/lanzaboote/blob/master/docs/getting-started/prepare-your-system.md)
- [Lanzaboote: Framework Secure Boot enrollment](https://github.com/nix-community/lanzaboote/blob/master/docs/getting-started/enable-secure-boot.md#framework-devices-enter-setup-mode)
- [Cloudflare unfiltered resolver endpoints](https://developers.cloudflare.com/1.1.1.1/infrastructure/network-operators/)
- [Blocky configuration](https://0xerr0r.github.io/blocky/latest/configuration/)
- [HaGeZi lists and Blocky formats](https://github.com/hagezi/dns-blocklists)
- [UniFi WireGuard VPN server](https://help.ui.com/hc/en-us/articles/115005445768-UniFi-Gateway-WireGuard-VPN-Server)
- [Tor Browser installation](https://support.torproject.org/tor-browser/getting-started/installing/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [Git hooks](https://git-scm.com/docs/githooks)
- [Framework Laptop 13 Pro Linux compatibility](https://frame.work/laptop13pro?tab=linux)
- [Intel thermal daemon](https://github.com/intel/thermal_daemon)
- [Linux VM sysctl documentation](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html)
- [Power Profiles daemon](https://upower.pages.freedesktop.org/power-profiles-daemon/)
- [VSCodium](https://vscodium.com/)
- [LSP for Sublime Text](https://lsp.sublimetext.io/client_configuration/)
- [Package Control settings](https://packagecontrol.io/docs/settings)
