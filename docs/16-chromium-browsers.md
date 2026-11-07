# Ungoogled Chromium privacy profile

Guide 16 · [All guides](README.md).

Ungoogled Chromium is installed as a separate compatibility browser. Firefox is
the general browser, and Tor Browser remains the anonymity browser.

The profile uses `pkgs.ungoogled-chromium`, which removes code specific to
Google web services, substitutes Google service domains, and blocks residual
internal requests to those domains. This deliberately includes normal Chrome
Web Store and Google Safe Browsing integration.

## Effective controls

NixOS-managed policy disables third-party cookies, search suggestions,
prediction, background mode, domain-reliability reporting, URL-keyed
collection, metrics, surveys, remote spell checking, Chromium Privacy Sandbox
advertising surfaces, browser-provided AI, and address/payment-card autofill.
WebRTC remains functional but does not advertise private interfaces.
DuckDuckGo is the default search provider without suggestion queries.

The browser's internal DNS client and browser-level DoH are disabled so it uses
the system resolver and local Blocky privacy filter. This retains UniFi and
WireGuard split-DNS routes. Verify the active path with:

```bash
resolvectl status
resolvectl query example.com
```

## Verify after the rebuild

```bash
command -v chromium
chromium --version
readlink -f "$(command -v chromium)"
```

The resolved path should contain `ungoogled-chromium`; the executable and
desktop application name remain `chromium`.

Open `chrome://policy`, select **Reload policies**, and confirm the managed
privacy controls. A **managed by your organization** message is expected: the
organization is this local NixOS configuration, not a remote administrator.

Open `chrome://extensions` and confirm that no unexpected extension is
installed. Do not install an unpacked extension and then forget to maintain it;
an outdated privileged extension is a browser security risk.

## Site compatibility adjustment

If a site depends on a Google browser service removed from ungoogled Chromium,
use the hardened Firefox profile rather than weakening this profile globally.

If a legacy login genuinely requires third-party cookies, temporarily change
this policy in `modules/nixos/browsers.nix`:

```nix
BlockThirdPartyCookies = false;
```

Test the next generation before making the exception permanent. Restore the
privacy setting after the affected workflow is complete; a dedicated browser
profile is preferable for persistent exceptions.

## Privacy boundary

Ungoogled Chromium is not Tor Browser and does not provide a shared browser
fingerprint or network anonymity. It also lacks Google Safe Browsing, so use
extra care with unknown links and downloads. NixOS, rather than the browser,
updates it; after every flake update, verify that the package remains on a
current security-supported Chromium release before switching generations.

## Primary references

- [ungoogled Chromium objectives and feature overview](https://github.com/ungoogled-software/ungoogled-chromium)
- [ungoogled Chromium extension limitations](https://github.com/ungoogled-software/ungoogled-chromium-wiki/blob/master/faq.md)
- [Chrome Enterprise policy list](https://chromeenterprise.google/policies/)
