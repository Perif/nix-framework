# Brave and ungoogled Chromium privacy profiles

Brave and ungoogled Chromium are installed as separate browser profiles. NixOS
supplies shared managed privacy policy, while a second Brave-only policy keeps
Google-backed security services and uBlock Origin Lite out of the ungoogled
profile. Neither browser is the anonymity browser; use Tor Browser for that.

The intended split is:

- **Brave:** the general Chromium-family browser, with Safe Browsing Standard
  Protection, managed uBlock Origin Lite, and Brave Shields;
- **ungoogled Chromium:** the Google-independent Chromium compatibility
  profile, without Chromium's built-in Google web-service dependencies.

## Effective controls

Both browsers receive these managed settings:

- third-party cookies, search suggestions, prediction, background mode,
  domain-reliability reporting, URL-keyed collection, metrics, surveys, and
  remote spell checking are disabled;
- Chromium Privacy Sandbox advertising surfaces and browser-provided AI are
  disabled;
- address and payment-card autofill are disabled;
- WebRTC remains functional but does not advertise private interfaces;
- DuckDuckGo is the default search provider without suggestion queries.

Brave additionally:

- force-installs uBlock Origin Lite in Optimal mode, with its maintained
  default lists and AdGuard URL Tracking Protection;
- keeps Safe Browsing Standard Protection enabled while disabling extended
  reporting and preventing bypass of known-dangerous interstitials;
- disables P3A, the daily usage ping, Web Discovery, Leo, Rewards, Wallet, VPN
  promotion, News, Talk promotion, and its private Tor window;
- keeps Brave Shields active as a second browser-native layer.

Ungoogled Chromium is supplied by `pkgs.ungoogled-chromium`. Upstream removes
code specific to Google web services, substitutes Google service domains, and
blocks residual internal requests to those domains. This deliberately includes
disabling Google Safe Browsing and normal Chrome Web Store integration. uBlock
Origin Lite is therefore not force-installed in this profile: silently
restoring its Web Store update channel would undermine the reason for selecting
the ungoogled build. Use Brave or the hardened Firefox profile for an
automatically updated content blocker and phishing/download reputation checks.

## Verify after the rebuild

```bash
command -v brave
command -v chromium
chromium --version
readlink -f "$(command -v chromium)"
```

The resolved Chromium path should contain `ungoogled-chromium`. Its command and
desktop application name remain Chromium.

Open each policy page:

```text
brave://policy
chrome://policy
```

Select **Reload policies**. Confirm that the shared controls are present and
that Brave also lists its Brave-specific controls. A **managed by your
organization** message is expected: the organization is this local NixOS
configuration, not a remote administrator.

Open Brave's extension page and confirm that uBlock Origin Lite is installed:

```text
brave://extensions
```

The uBOL dashboard should show Optimal filtering, the default ruleset, and
AdGuard URL Tracking Protection. It can take several seconds after first
launch for managed extension settings to appear.

Open `chrome://extensions` in ungoogled Chromium and confirm that no unexpected
extension was installed. The absence of the managed Chrome Web Store uBOL
extension is intentional. Do not install an unpacked extension and then forget
to maintain it; an outdated privileged extension is a browser security risk.

## DNS and UniFi behavior

The browsers' internal DNS client and browser-level DoH are disabled by policy
so both use the system resolver and local Blocky privacy filter. Blocky forwards
allowed names over encrypted DoH, and a more-specific DNS suffix imported with
a UniFi WireGuard profile can still handle private names. Verify the active
path with:

```bash
resolvectl status
resolvectl query example.com
```

This avoids a browser DoH setting silently bypassing the filter or split-DNS
routes in `docs/NETWORKING.md`. Firefox's direct unfiltered DoH remains the
documented false-positive recovery path, and Tor Browser remains separate.

## Site compatibility adjustment

No content blocker can promise to identify every tracker, and stronger blocking
can break a site. In Brave, first use uBOL's per-site control or Brave Shields
for the smallest possible exception. Do not globally disable Safe Browsing or
extension updates to repair one website.

If a site depends on a Google browser service removed from ungoogled Chromium,
open that site in Brave instead of weakening the ungoogled package globally.

If a legacy login genuinely requires third-party cookies, temporarily change
this policy in `modules/nixos/browsers.nix`:

```nix
BlockThirdPartyCookies = false;
```

Test the next generation before making it permanent:

Follow [apply a change](install/customization.md), including its temporary
activation and verification steps.

Restore the privacy setting after the affected workflow is complete. Prefer a
dedicated browser profile for a persistent compatibility exception.

## Privacy boundary

"No unique identifier" and "all trackers removed" are not technically
verifiable browser guarantees. A site can assign an identifier with first-party
cookies or storage, associate activity with an account or public IP address, or
derive a fingerprint from browser and device characteristics. Ungoogled
Chromium removes Google integration; it does not provide Tor Browser's shared
fingerprint or network anonymity. Avoid optional fingerprint-randomization
flags unless they solve a measured problem, because an unusual configuration
can itself make a browser profile easier to distinguish.

Brave's force-installed uBOL package is obtained and updated through the Chrome
Web Store. Brave Safe Browsing and filter-list updates also require network
access; those limited security paths are retained deliberately. Ungoogled
Chromium does not use those Google-backed protections, so use extra care with
unknown links and downloads.

NixOS, rather than the browser, updates ungoogled Chromium. After each flake
update, verify that `chromium` and `ungoogled-chromium` remain on a current,
security-supported Chromium release before switching generations.

## Primary references

- [uBlock Origin Lite in the Chrome Web Store](https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh)
- [uBO Lite managed settings](https://github.com/uBlockOrigin/uBOL-home/wiki/Managed-settings)
- [ungoogled Chromium objectives and feature overview](https://github.com/ungoogled-software/ungoogled-chromium)
- [ungoogled Chromium extension limitations](https://github.com/ungoogled-software/ungoogled-chromium-wiki/blob/master/faq.md)
- [Brave blocking goals and limitations](https://github.com/brave/brave-browser/wiki/Blocking-goals-and-policy)
- [Brave policy on Linux](https://support.brave.com/hc/en-us/articles/360039248271-Group-Policy)
- [Chrome Enterprise policy list](https://chromeenterprise.google/policies/)
