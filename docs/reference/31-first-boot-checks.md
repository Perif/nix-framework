# Extended hardware and service checks

Guide 31 · [All guides](../README.md).

Use this reference after the [essential first-boot checks](../install/05-first-boot.md).
Run only checks for enabled features. These commands require the installed laptop;
Nix evaluation and CI do not establish physical hardware behavior.

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

Follow [apply and verify a change](../install/06-customization.md), then recheck
`timedatectl status`.

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

Capture a first-boot baseline with `framework-power-report > power-baseline.json`.
Follow [browser hardware-decoding verification and sleep checks](../22-power-measurements.md)
before treating driver installation as proof of acceleration or reliable resume.
The report stays local and may include kernel-log device identifiers; review it
before sharing. Missing permissions/sensors are reported, not treated as success.

The expected performance values and safe use of the temporary performance
profile are documented in `docs/21-performance.md`. Do not force thermald past a
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
`docs/08-networking.md` before changing DNS, allowlisting a domain, or importing a
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
`docs/07-security-privacy.md` documents the per-network override for a network
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
```

After hibernation resumes successfully, test `systemctl suspend-then-hibernate`
separately and confirm both resume and the lock screen.

Do not enable TPM2 auto-unlock until cold boot, hibernation, resume, and password
recovery have all been tested. Continue with `docs/24-fingerprint-tpm.md` afterward.

Select the matching panel ICC using [display setup](../09-display.md), then follow
[EasyEffects speaker setup](../10-audio.md#easyeffects-speaker-preset) to associate
the bundled preset with the built-in speaker device and route. Verify that
switching to headphones selects the Flat fallback. These profiles are
installed declaratively; the panel and audio-route identities need checking
on this laptop before use.

For the DC-Elite audio path:

```bash
aplay -l
dc-elite-alsa-config
```

Follow `docs/10-audio.md` before writing the generated ALSA configuration.

Strawberry, qobuz-player and MusicBrainz Picard are installed for the login user.
Use Strawberry for local playback, follow the [qobuz-player setup](../10-audio.md#qobuz-player--qobine)
for streaming and explicit DC-Elite device selection, and use Picard for tagging.
Only one direct-ALSA player can use the DAC at a time.

Keep QBZ disabled unless you have supplied an independently maintained Nix
package through `qbz.packageFile`. See the optional package configuration in [audio setup](../10-audio.md).

Open Firefox and verify `about:policies`, `about:addons`, and
`about:preferences#privacy`. The uBlock Origin advanced controls are enabled,
but its per-site dynamic rules remain user-owned; follow `docs/15-firefox.md` to
activate medium mode if that stricter uMatrix-like behavior is wanted.

Follow [workstation application setup](../12-workstation-apps.md) for Wine, KeePassXC
and 1Password import, direnv, NH, mpv, and Open WebUI's first admin account.
Check [build tuning](../21-performance.md#measuring-build-and-inference-contention)
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
`docs/18-local-ai-development.md`.

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
`docs/18-local-ai-development.md` to choose a tool-capable Ollama model or serve a
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
`docs/16-chromium-browsers.md` for the exact controls, Safe Browsing boundary, and
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

The last two commands should both print `true`. See `docs/14-git-safety.md` for a
manual staged scan, false-positive handling, and the limits of client-side
hooks.

Launch Tor Browser from Plasma or run `tor-browser`, complete its connection
screen, and verify it at `https://check.torproject.org/`. Do not add extensions
or copy the hardened Firefox profile into Tor Browser; see
`docs/17-tor-browser.md`.

For a UniFi WireGuard client profile, follow `docs/08-networking.md`. The profile
contains a private key, so never paste it into `settings.nix`, commit it, or
store it in the Nix store.
