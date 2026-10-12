# Security and privacy operations

Guide 07 · [All guides](README.md).

This build favors controls that are useful on a daily laptop without disabling
hibernation, rootless containers, browser compatibility, or ordinary VPNs.
Security still depends on timely flake updates, strong recovery credentials,
firmware updates, and backups kept outside the laptop.

## Network identity privacy

NetworkManager applies these defaults to newly created connections:

- Wi-Fi scanning uses a fresh random locally administered MAC address.
- An associated Wi-Fi network uses `stable-ssid`, a randomized address derived
  per SSID. Different SSIDs do not see the same hardware identity.
- Ethernet uses a stable randomized address per connection profile.
- DHCPv4 and DHCPv6 do not receive the laptop's persistent hostname.
- IPv6 temporary addresses are generated and preferred for outbound traffic.
- The inbound NixOS firewall is explicitly enabled and no service opens a port
  unless its module requests one. SSH remains disabled while the authorized-key
  list is empty.

Stable randomization avoids cross-network correlation while retaining a
consistent DHCP/captive-portal identity on each network. A network that uses
MAC allowlisting may require a profile-specific override. List profiles, apply
the minimum override, and reconnect:

```bash
nmcli connection show
sudo nmcli connection modify "REPLACE_WITH_WIFI_PROFILE" \
  802-11-wireless.cloned-mac-address permanent
sudo nmcli connection down "REPLACE_WITH_WIFI_PROFILE"
sudo nmcli connection up "REPLACE_WITH_WIFI_PROFILE"
```

For a fresh address on every connection instead of one stable address per
network:

```bash
sudo nmcli connection modify "REPLACE_WITH_WIFI_PROFILE" \
  802-11-wireless.cloned-mac-address random
```

That stronger mode can invalidate captive-portal registration and create a new
DHCP lease on every reconnect. Return the per-profile value to an empty/default
value to inherit the declarative `stable-ssid` policy again:

```bash
sudo nmcli connection modify "REPLACE_WITH_WIFI_PROFILE" \
  802-11-wireless.cloned-mac-address ""
```

Bluetooth support remains installed, but the radio does not power on at boot.
Enable it from Plasma only when needed and turn it off afterward.

## Location and local time

GeoClue is disabled even though Plasma enables it by default. This prevents
desktop components from requesting automatic location for travel-based time
zones, weather, or Night Color. Firefox geolocation remains separately disabled
by its managed profile.

During installation, `nix run .#detect-timezone` performs a one-time HTTPS
public-IP lookup to ipapi.co and saves the returned IANA zone in `settings.nix`.
The provider sees the installer's public IP; VPNs/proxies can affect the result.
An explicit `timeZone`, or `--timezone Area/City`, skips the lookup. This does
not enable ongoing geolocation or change the installed desktop policy.

Accurate time does not require location. `systemd-timesyncd` synchronizes the
system clock over NTP, and the explicit IANA value in `settings.timeZone`
converts that clock to local wall time and applies daylight-saving transitions
for Plasma. Verify both after installation:

```bash
timedatectl status
timedatectl timesync-status
systemctl is-active systemd-timesyncd.service
```

When travelling, replace only `timeZone` in `/etc/nixos/settings.nix`, rebuild,
and keep the Plasma clock widget set to **Local**. Fully automatic travel-based
zone changes would require restoring a location source and are deliberately not
part of this privacy policy.

## Private DNS with local, reversible filtering

System applications use systemd-resolved through a loopback-only Blocky
service. Blocky forwards allowed queries to Cloudflare's standard, unfiltered
resolver over DoH on HTTPS port 443 and applies HaGeZi Normal plus the
full TIF threat feed locally. It exposes no LAN or HTTP control
listener, stores no per-query log, and redacts operational log details.
Automatic DNS supplied by ordinary DHCP networks is ignored, and no plaintext
or alternate-provider fallback is added.

Firefox uses the unfiltered DoH endpoint directly. This is intentional: the
browser's uBlock Origin policy provides its tracker filtering, while direct DoH
offers a recovery path when the system list causes a false positive. The
declarative `dns.filtering.allowlist` can then add a narrow exception, or the
entire local filter can be disabled in a temporary Nix generation without
changing the upstream provider.

No filter or public resolver can guarantee that every name remains reachable
in every jurisdiction. Local filtering does not bypass authoritative-domain
removal, IP/SNI blocking, routing failures, or legal orders. Tor Browser is the
separate tool for browsing through the Tor network when local DNS or network
censorship is the problem. DoH hides queries from the local network path, not
from the resolver operator; Cloudflare's documented public-resolver privacy
commitments remain part of this provider choice. Configuration, false-positive
recovery, UniFi private-name handling, and verification are in
`docs/08-networking.md`.

## Host hardening

The build additionally:

- limits `sudo` execution to members of `wheel` and requires the account
  password for privileged commands, while retaining fingerprint login and
  Plasma session unlock;
- locks the configured user's Plasma session after five minutes of inactivity,
  requires authentication without a grace period, and locks immediately after
  resume;
- disables GeoClue while keeping automatic NTP clock synchronization and the
  explicit `settings.timeZone` used by Plasma;
- keeps the loopback-only, sandboxed Ollama service inactive until it is
  explicitly started for local-model work;
- keeps Open WebUI loopback-only and signup-disabled; the first administrator is
  created through a one-shot root-only bootstrap file rather than an open signup
  window;
- permits Nix-daemon requests only from `root` and the login account selected
  by `settings.user.name`, while keeping only `root` in `trusted-users`;
- hides kernel pointers and kernel messages from unprivileged users;
- restricts ptrace to parent/authorized debugging relationships;
- disables unprivileged BPF while retaining privileged BPF and hardens the BPF
  JIT against address disclosure;
- rejects IPv4 redirects, source-routed packets, and broadcast ICMP echo;
- rejects IPv6 redirects and all IPv6 source-routing headers while retaining
  ordinary router advertisements and temporary addresses;
- discards process core-image payloads, which can contain decrypted secrets;
- retains encrypted-system journals for at most 14 days and 512 MiB;
- avoids broadcasting single-label lookups with LLMNR;
- keeps Blocky's DNS and control surface on loopback, omits its unauthenticated
  HTTP API, and disables per-query storage;
- keeps sensitive commands prefixed with a space out of Zsh history and does
  not stream each command into all concurrent shells;
- scans added, staged Git content locally for credentials and high-confidence
  PII before a commit, while redacting credential findings;
- keeps the proprietary-package exception to the exact Sublime, Brave, OneTab,
  and Enhancer for YouTube derivation names instead of globally allowing
  unfree software;
- keeps terminal paste protection enabled, treats bracketed paste as subject to
  checks, asks before terminal programs read or write the desktop clipboard,
  disables automatic copy-on-select, and confirms before closing a surface;
- seeds Sublime's external plug-in installation list with Package Control, EditorConfig,
  LSP, and syntax-only Nix support while keeping language-server executables in
  the pinned Nix closure;
- powers Bluetooth off at boot;
- stages signed Secure Boot through Lanzaboote.

Kernel module locking and `security.protectKernelImage` are not enabled:
module locking is a poor fit for laptop hotplug, and NixOS implements protected
kernel images by disabling hibernation. Unprivileged user namespaces remain
available because the Nix sandbox and rootless Podman require them.

Verify the added IPv6 controls after a rebuild:

```bash
sysctl \
  net.ipv6.conf.all.accept_redirects \
  net.ipv6.conf.default.accept_redirects \
  net.ipv6.conf.all.accept_source_route \
  net.ipv6.conf.default.accept_source_route
```

The first two values must be `0` and the final two must be `-1`.

The performance module does not disable CPU vulnerability mitigations, weaken
the Nix sandbox, force unsupported hardware drivers, or override firmware
thermal limits. Its settings and measurement boundaries are documented in
`docs/21-performance.md`.

## Storage maintenance

Smartd monitors locally discovered SMART-capable storage, including NVMe, and
records health failures in the journal while notifying logged-in terminals
and the configured Plasma user's session. A root-owned marker persists across
logout/reboot and produces hourly reminders until acknowledged. See
`INSTALL.md` for the non-destructive notification test and acknowledgement.
It deliberately has no mail dependency or remote reporting endpoint.

Snapper takes a root snapshot at boot and hourly timeline snapshots, then keeps
6 hourly, 7 daily, 4 weekly, and 6 monthly snapshots. Separate `/home`, `/nix`,
`/var/log`, and `/var/lib/private/ollama` subvolumes are not included. Existing
installs need the documented model-store migration before activation. Boot
image retention is separately capped at three generations in both boot modes;
check EFI free space before updates. Btrfs scrubs the filesystem monthly,
and Nix store optimization runs weekly at low priority on AC power.

Check their state with:

```bash
systemctl is-active smartd.service
sudo smartctl --scan-open
systemctl list-timers --all \
  'btrfs-scrub-*' \
  snapper-timeline.timer \
  snapper-cleanup.timer \
  nix-optimise.timer
sudo snapper -c root list
sudo btrfs scrub status /
```

## Open WebUI state and first-admin setup

Open WebUI state lives under `/var/lib/open-webui`, including local accounts,
chats, uploads, and its SQLite database. That path is part of the root subvolume,
so deleted chats, deleted uploads, previous account rows, and older database
states can remain recoverable from existing root snapshots until Snapper expires
them. The data stays local and benefits from full-disk encryption while the disk
is locked, but app-level deletion is not immediate snapshot erasure after login.
This configuration does not perform automatic destructive snapshot cleanup for
Open WebUI; review and delete root snapshots manually only when you have decided
that losing those rollback points is acceptable.

Open WebUI is installed disabled-at-boot, listens only on `127.0.0.1`, and keeps
account signup off. On a fresh database, `open-webui.service` refuses to start
until you run `sudo webui-bootstrap` from an interactive terminal. The helper
prompts for the admin email, display name, and password; writes them once to a
root-only environment file in `/run`; writes a non-secret start permit for the
service guard; starts Open WebUI with the upstream `WEBUI_ADMIN_EMAIL` and
`WEBUI_ADMIN_PASSWORD` bootstrap variables; waits until the local SQLite database
contains the matching admin row and the HTTP listener is ready; removes the
bootstrap files; and restarts the service so the long-running process no longer
has the bootstrap password in its environment. It refuses to overwrite existing
users or admins, but an empty database left by a failed startup is retryable.
If the helper is terminated normally, it removes the runtime files before
exiting. If the process is killed hard or the machine loses power, stop
`open-webui.service`, remove stale `/run/open-webui-bootstrap.env` and
`/run/open-webui-bootstrap.start` without printing their contents, then rerun
`sudo webui-bootstrap`; the helper will refuse any non-empty existing user state.
Store the new password in your password manager before relying on the service.

A local snapshot does not protect against drive failure, theft, or destructive
filesystem damage. Keep versioned, encrypted backups on another device or
service and test restoration.

## Browser and VPN boundary

Firefox uses HTTPS-only mode, direct unfiltered encrypted DNS, strict tracking
protection, anti-fingerprinting controls, blocked permission prompts, Safe
Browsing, and an auditable pinned extension set. The policy forbids silent
plaintext fallback but is unlocked for VPN split-DNS compatibility.

uMatrix was replaced by uBlock Origin's maintained dynamic filtering. Mozilla
Multi-Account Containers was added for explicit first-party identity separation.
No canvas-spoofing, URL-cleaner, or additional script-blocking extension was
added because those functions overlap existing controls and every privileged
extension is another attack and fingerprinting surface. See `docs/15-firefox.md`
for the complete policy and optional uBO medium-mode steps.

Brave and ungoogled Chromium use shared NixOS-managed privacy policy and the
locally filtered system resolver:
third-party cookies, telemetry, prediction, ad-personalization surfaces,
browser AI, and unnecessary background services are disabled. Both browsers
use the system resolver so UniFi/WireGuard split-DNS routes remain effective.

Brave alone force-installs uBlock Origin Lite in Optimal mode and keeps Safe
Browsing Standard Protection. It also disables P3A, usage ping, Web Discovery,
Leo, Rewards, Wallet, VPN promotion, News, and Talk promotion. Ungoogled
Chromium removes built-in Google service dependencies, including normal Chrome
Web Store and Safe Browsing integration; it is not a substitute for Tor
Browser and should be used cautiously for unknown links or downloads. The
exact controls, expected managed-browser label, site-breakage procedure, and
residual privacy boundary are in `docs/16-chromium-browsers.md`.

Tor Browser is installed separately and is intentionally left at Tor Project's
shared browser configuration. Ordinary Firefox is not pointed at a Tor proxy,
and no extra Tor Browser extension is installed. See `docs/17-tor-browser.md`.

NetworkManager already provides native WireGuard support, and `wireguard-tools`
adds `wg` and `wg-quick`. No inbound firewall port is opened merely by
installing the client. UniFi-exported client profiles can be imported through
NetworkManager; see `docs/08-networking.md` for private-key and split-DNS handling.

## Git disclosure guard

Home Manager installs Gitleaks and a managed global pre-commit hook. Gitleaks
checks the staged diff for credentials and redacts matched values. A local
scanner blocks valid-looking SSNs, Luhn-valid payment-card numbers, and
checksum-valid IBANs; lower-confidence email, phone, birth-date, and precise
location matches produce review warnings without displaying the value.

This is a defense against accidental commits, not a security boundary. Git
allows hooks to be bypassed, a repository can override `core.hooksPath`, and a
developer can push from an unmanaged machine. Important shared repositories
should run an equivalent secret scan in protected CI. Configuration,
verification, exceptions, and repository-hook compatibility are documented in
`docs/14-git-safety.md`.

## Update and verification routine

Review upstream changes before updating the lock file:

Follow [update pinned dependencies](27-updates.md) and the
[common change workflow](install/06-customization.md). Pause to verify the result
before promotion; use the reboot path for boot-related updates.

After security-relevant updates, reboot and check:

```bash
bootctl status
sudo sbctl status
sudo sbctl verify
fwupdmgr get-updates
systemctl --failed
```

The `sbctl` checks become authoritative only after completing the signed Secure
Boot procedure in `docs/00-install.md`.

## Primary references

- [NetworkManager MAC randomization](https://www.networkmanager.dev/docs/api/latest/NetworkManager.conf.html)
- [NetworkManager cloned MAC semantics](https://www.networkmanager.dev/docs/libnm/latest/NMSettingWireless.html)
- [Firefox enterprise policies](https://mozilla.github.io/policy-templates/)
- [Chrome Enterprise policies](https://chromeenterprise.google/policies/)
- [uBlock Origin Lite managed settings](https://github.com/uBlockOrigin/uBOL-home/wiki/Managed-settings)
- [Brave blocking policy](https://github.com/brave/brave-browser/wiki/Blocking-goals-and-policy)
- [Cloudflare unfiltered resolver endpoints](https://developers.cloudflare.com/1.1.1.1/infrastructure/network-operators/)
- [systemd-resolved encrypted DNS configuration](https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html)
- [Blocky configuration](https://0xerr0r.github.io/blocky/latest/configuration/)
- [HaGeZi blocklists](https://github.com/hagezi/dns-blocklists)
- [systemd-coredump disabling guidance](https://www.freedesktop.org/software/systemd/man/latest/systemd-coredump.html#Disabling%20coredump%20processing)
- [UniFi WireGuard VPN server](https://help.ui.com/hc/en-us/articles/115005445768-UniFi-Gateway-WireGuard-VPN-Server)
- [Tor Browser safe-use guidance](https://support.torproject.org/tor-browser/security/using-tb-safely/)
- [Lanzaboote Secure Boot guide](https://github.com/nix-community/lanzaboote/blob/master/docs/getting-started/prepare-your-system.md)
- [Ghostty security-relevant configuration](https://ghostty.org/docs/config/reference)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [Git hooks](https://git-scm.com/docs/githooks)
- [Nix daemon access control](https://nix.dev/manual/nix/latest/command-ref/conf-file.html#conf-allowed-users)
