# Private filtered DNS and UniFi WireGuard

This build runs Blocky locally for system-wide tracker blocking, forwards
allowed queries to an unfiltered provider over encrypted DNS, and includes
WireGuard client support. Filtering has a one-file allowlist and off switch;
Firefox deliberately retains a direct unfiltered encrypted-DNS path for
recovery. No VPN key or connection profile belongs in this repository: Nix
store paths are readable by local users, and a UniFi export contains the client
private key.

## DNS design

`settings.nix` owns the provider, bootstrap addresses, and filtering policy:

```nix
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
```

- Blocky listens only on `127.0.0.1:5353` and `[::1]:5353`; no LAN or web/API
  listener is opened;
- systemd-resolved routes ordinary queries to those loopback listeners;
- resolved retains its early-boot ordering; Blocky starts independently after
  networking. System DNS can briefly fail until Blocky is ready. Do not order
  resolved after Blocky: resolved runs before `sysinit.target`, while Blocky
  is a regular service that starts after it, creating a boot dependency cycle;
- Blocky forwards allowed queries to the standard, unfiltered Cloudflare
  resolver over DNS-over-HTTPS on port 443;
- the two bootstrap addresses resolve the DoH hostname and list-download
  hostname without creating a loop through systemd-resolved;
- HaGeZi Normal's wildcard list provides broad everyday ad and tracker blocking
  with a low restriction risk, while full TIF adds broader malware, phishing,
  scam, and command-and-control coverage;
- Blocky starts DNS even if the list download is temporarily unavailable and
  refreshes it every 24 hours; availability wins over filtering during an
  initial download failure;
- blocked answers use NXDOMAIN with a one-minute negative TTL, so an allowlist
  fix takes effect quickly;
- per-query logging is disabled, operational logs redact domain and response
  details, and there is no statistics database;
- Firefox uses the same unfiltered provider directly over DoH. This bypasses
  Blocky by design and remains a known-good browser for a false positive;
- DHCP-provided DNS is ignored by default, preventing an access point or ISP
  from silently replacing the resolver;
- there is no plaintext or alternate-provider fallback;
- local DNSSEC validation is disabled because an incorrectly signed domain can
  otherwise look blocked. Cloudflare performs DNSSEC validation upstream;
- LLMNR is disabled so single-label requests are not broadcast to the LAN.

The standard `1.1.1.1` service is the explicitly unfiltered upstream. Do not use
`1.1.1.2`, `1.1.1.3`, `security.cloudflare-dns.com`, or
`family.cloudflare-dns.com` when avoiding provider-controlled category filters
is the goal. The only intentional content policy here is the visible local
HaGeZi Normal and full TIF combination.

This does not guarantee universal reachability. A domain can still be removed
at its authoritative source, blocked by IP/SNI, affected by routing, or subject
to a legal order. Tor Browser is the appropriate separate tool when local
network censorship must be bypassed.

Encrypted DNS is private from the Wi-Fi operator, ISP path, and passive local
observers; it is not anonymous from the chosen resolver. Cloudflare can see the
client address and query while resolving it, subject to its public-resolver
privacy commitments. The public list host sees periodic list downloads but not
DNS queries. Tor Browser avoids this host DNS path for Tor browsing and
provides the stronger separation when anonymity is required.

Mullvad's public encrypted DNS was considered but not selected: Mullvad has
announced that the service will be discontinued on November 2, 2026.

The list URLs are intentionally live rather than stored in `flake.lock`, because
tracker and threat domains change continuously. Their content is data, not
executable code, but a publisher or delivery failure can still cause
over-blocking or leave the system temporarily unfiltered. The Firefox bypass,
short block TTL, declarative allowlist, and tested off switch are the
availability controls for that external dependency.

Full TIF is now the default alongside Normal, consistent with
[HaGeZi's recommendation](https://github.com/hagezi/dns-blocklists/blob/main/CHEATSHEET.md).
TIF Medium and Mini trade threat coverage for smaller download and memory
requirements. Mini is not established as a lower-false-positive policy tier;
the earlier explanation overstated that argument. TIF also does not mean
blanket blocking of newly registered domains (NRD is a separate list).

Measure this implementation on the laptop, including a full daily refresh:

```bash
systemctl show blocky.service -p MemoryCurrent -p MemoryPeak
journalctl -u blocky.service --since '25 hours ago'
resolvectl query example.com
```

Compare memory with your model workload running and check your usual websites.
There is no measured Blocky memory budget or refresh benchmark supplied with
this build; RAM figures for AdGuard Home are not Blocky measurements. If the
cost is excessive, replace only `tif.txt` with `tif.medium.txt` or `tif.mini.txt`
in `settings.nix` and rebuild. Keep Normal and use exactly one TIF variant.

## Verify DNS after a rebuild

```bash
systemctl is-active blocky.service
systemctl show blocky.service -p ActiveState -p SubState
resolvectl status
resolvectl query example.com
ss -lntup | grep ':5353'
readlink -f /etc/resolv.conf
```

Expected results:

- Blocky is active and has only loopback listeners on port 5353.
- Global DNS Servers lists `127.0.0.1:5353` and `[::1]:5353`.
- `DNS over TLS` is not used on the local resolved-to-Blocky hop; Blocky's
  upstream transport is DoH on HTTPS port 443.
- `/etc/resolv.conf` points into `/run/systemd/resolve/`.
- Firefox Settings > Privacy & Security > DNS over HTTPS shows
  `https://cloudflare-dns.com/dns-query`.

Cloudflare's browser check can verify the connection interactively:

```text
https://1.1.1.1/help
```

## Recover from a false positive

First open the same address in Firefox. Firefox's direct DoH bypasses Blocky; if
the site works there but fails in ungoogled Chromium or a system application,
the local list is the likely difference. Add only the required domain and its
needed subdomains in `/etc/nixos/settings.nix`:

```nix
dns.filtering.allowlist = [
  "example.com"
  "*.example.com"
];
```

Evaluate and activate the change temporarily, then flush the stub cache:

```bash
cd /etc/nixos
nix-check
nix-test
sudo systemctl restart blocky.service
resolvectl flush-caches
resolvectl query example.com
```

If it works, make the generation permanent with `nix-switch`. If it does not,
use `journalctl -u blocky.service --since today`; query names remain redacted.
Keep allowlist entries narrow because `*.example.com` exempts every subdomain.

For an immediate diagnostic bypass, set `dns.filtering.enable = false`, run
`nix-test`, and retry. That changes systemd-resolved back to the configured
unfiltered upstream over strict DoT; restore `true` once the cause is known.
Firefox and Tor Browser do not need this toggle.

## Captive portals and restrictive networks

Blocky's upstream uses HTTPS port 443, which is more commonly permitted than
DoT port 853, but a captive portal may prevent all outside traffic until login.
Use Plasma's portal notification first. Firefox's direct DoH is also on port
443, so it is a useful second check after the portal accepts the connection.

If both fail, the network—not the privacy list—is probably blocking outside
traffic. Do not permanently weaken encrypted DNS for one network. Use the
portal's documented login address or a trusted mobile hotspot, then reconnect.
The `dns.filtering.enable = false` diagnostic above falls back to strict DoT,
not plaintext DNS, so it does not silently disclose queries.

## UniFi: create and import a WireGuard client

UniFi does not require a special Linux client. NetworkManager supports
WireGuard natively, Plasma can control the imported connection, and the
installed `wireguard-tools` package provides `wg` and `wg-quick`.

Before troubleshooting the laptop, review the UniFi network/VLAN assigned to
it. UniFi Content Filtering and Ad Blocking are DNS-level controls that can
redirect ordinary DNS to the gateway, while client DoH/DoT may bypass them or
be denied by a separate firewall rule. If the goal is no category filtering,
set the laptop's applicable **Settings > CyberSecure > Content Filter** policy
to **Off**, disable UniFi Ad Blocking for that client/network, and confirm no
country, application, or custom firewall rule blocks the resolver endpoints or
DoH over HTTPS/TCP 443. Strict DoT/TCP 853 is used only when the local filter is
disabled. Keep IDS/IPS enabled unless a specific false positive is confirmed;
it is independent of selecting an unfiltered DNS resolver.

In the UniFi Network application:

1. Open **Settings > VPN** and create or open the WireGuard VPN server.
2. Add a client for this laptop.
3. Choose the desired remote networks or full-tunnel policy.
4. Download the client configuration file.

Treat the downloaded file as a password. On the laptop, restrict it before
importing:

```bash
chmod 600 "$HOME/Downloads/REPLACE_WITH_UNIFI_PROFILE.conf"
nmcli connection import type wireguard \
  file "$HOME/Downloads/REPLACE_WITH_UNIFI_PROFILE.conf"
nmcli -f NAME,TYPE connection show
```

Use the imported name printed by NetworkManager:

```bash
WG_NAME="REPLACE_WITH_IMPORTED_CONNECTION_NAME"
nmcli connection up "$WG_NAME"
sudo wg show
ip route
resolvectl status
```

Test a private UniFi address that should be reachable. A public-IP check is
meaningful only for a full-tunnel profile:

```bash
curl --fail https://ifconfig.me
```

After the connection works, place an encrypted recovery copy in a password
manager or offline vault, then remove the downloaded copy. Deleting is not a
secure erase on Btrfs/SSD media, which is why the disk is encrypted from the
start.

## UniFi private DNS and split tunnels

An imported profile's manually specified DNS server is not the same as DNS
learned automatically from a Wi-Fi DHCP lease, so it can still be used. For a
split tunnel, give the UniFi DNS server a route-only private suffix so only
those names leave the public encrypted resolver. Replace both examples with
the actual gateway address and domain used by the UniFi network:

```bash
WG_NAME="REPLACE_WITH_IMPORTED_CONNECTION_NAME"
sudo nmcli connection modify "$WG_NAME" \
  ipv4.dns "192.168.1.1" \
  ipv4.ignore-auto-dns yes \
  ipv4.dns-search "~REPLACE_WITH_PRIVATE_DOMAIN"
nmcli connection down "$WG_NAME"
nmcli connection up "$WG_NAME"
resolvectl status
```

The leading `~` makes this a routing suffix, not a suffix appended to every
single-label lookup. For example, `~home.arpa` routes only `*.home.arpa` to the
UniFi DNS server. Do not use a root `~.` route on a split tunnel unless all DNS
should use the VPN resolver.

If the UniFi connection is full-tunnel (`0.0.0.0/0` and optionally `::/0` in
`AllowedIPs`), the configured public encrypted resolver is reached through the
tunnel. Verify routes and DNS after every profile change. Installing the client
does not open UDP 51820 in the laptop firewall; client-initiated traffic and
replies work without an inbound rule.

## Primary references

- [Blocky configuration](https://0xerr0r.github.io/blocky/latest/configuration/)
- [HaGeZi lists and Blocky formats](https://github.com/hagezi/dns-blocklists)
- [Cloudflare resolver endpoints and filtering levels](https://developers.cloudflare.com/1.1.1.1/infrastructure/network-operators/)
- [Cloudflare public-resolver privacy commitments](https://developers.cloudflare.com/1.1.1.1/privacy/public-dns-resolver/)
- [Cloudflare systemd-resolved DoT syntax](https://developers.cloudflare.com/1.1.1.1/setup/linux/)
- [systemd-resolved routing behavior](https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.html)
- [NetworkManager configuration reference](https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/NetworkManager.conf.html)
- [UniFi WireGuard VPN server](https://help.ui.com/hc/en-us/articles/115005445768-UniFi-Gateway-WireGuard-VPN-Server)
- [UniFi content and domain filtering](https://help.ui.com/hc/en-us/articles/12568927589143-Content-and-Domain-Filtering-in-UniFi)
- [UniFi gateway ad blocking](https://help.ui.com/hc/en-us/articles/9794438523799-UniFi-Gateway-Ad-Blocking)
- [WireGuard quick start](https://www.wireguard.com/quickstart/)
- [Mullvad encrypted-DNS service notice](https://mullvad.net/en/help/dns-over-https-and-dns-over-tls)

## Optional Wi-Fi power-saving override

`settings.nix` provides a three-way NetworkManager default:

```nix
network.wifiPowerSave = null;
```

| Value | Behavior |
| --- | --- |
| `null` (default) | Do not set an extra global power-saving policy. |
| `false` | Disable Wi-Fi power saving; a reliability troubleshooting option. |
| `true` | Enable Wi-Fi power saving; may affect latency or reliability. |

An [Intel BE211 Series 3 user configuration](https://github.com/jbrake/nixos-config/blob/main/hosts/framework-intel-core-ultra/configuration.nix)
disables it for recurring `iwlmld` beacon-loss disconnects. That observation is
not proof your laptop needs the workaround. Start with `null`; inspect
`journalctl -b -k` for repeated disconnect/beacon-loss symptoms first.

After changing the value and rebuilding, reconnect Wi-Fi to apply the policy.
NetworkManager maps false to `wifi.powersave=2` and true to `wifi.powersave=3`
in its global connection defaults. A saved connection's explicit override
still wins. Inspect it with:

```bash
nmcli connection show --active
nmcli -g 802-11-wireless.powersave connection show 'YOUR_CONNECTION_NAME'
sudo NetworkManager --print-config
```

A saved value of `0` means use the global default; `1` means leave the current
setting unchanged. If you previously set a per-connection override and want
this Nix default to apply, deliberately set that connection back to `0` in
NetworkManager, then reconnect. Returning the Nix option to `null` removes the
global override after rebuilding; it does not erase custom saved profiles.
Disabling power saving may increase battery draw; compare reliability and
battery use before retaining it.
