# Firefox privacy and security profile

Guide 15 · [All guides](README.md).

The declarative Firefox profile lives in `home/modules/firefox.nix`. Browser
updates, extension versions, policies, and preferences are pinned through the
Nix flake rather than installed ad hoc.

## Installed extensions

- uBlock Origin
- NoScript
- OneTab
- Privacy Badger
- Enhancer for YouTube
- Decentraleyes
- Bypass Paywalls Clean
- Skip Redirect
- Mozilla Multi-Account Containers
- KeePassXC-Browser when `features.keepassxc` is enabled (the default)

Bypass Paywalls Clean uses the publisher's signed 4.4.6.6 XPI, kept unmodified
in `pkgs/bypass-paywalls-clean/`. The publisher's rolling upload list removed
previously pinned releases, so fresh builds now use the reviewed local artifact.
Its SHA-256 is checked by Nix before packaging, and the portable
`bypass-paywalls-clean` flake check verifies ZIP integrity, manifest version and
extension ID, signing metadata, and the preserved MIT license.

See the [source provenance and update instructions](../pkgs/bypass-paywalls-clean/PROVENANCE.md)
for the publisher URL and verified hash. The extension remains `magnolia@12.34`;
Firefox's signature enforcement is unchanged. Checking the archive's signing
metadata does not independently validate Mozilla's signature chain.

KeePassXC native messaging is configured by Home Manager. Enable browser
integration and pair the database interactively; see the
[1Password migration guide](12-workstation-apps.md#keepassxc-and-1password-migration).

## uMatrix replacement

uMatrix was removed because its upstream repository has been archived since
2021. Installing an unmaintained extension with access to every page would add
avoidable browser attack surface.

uBlock Origin is the replacement. Its maintained dynamic-filtering feature can
provide RequestPolicy/uMatrix-like source, destination, and request-type
control. The Firefox enterprise policy enables uBO's advanced-user controls,
but deliberately does not overwrite mutable per-site rules.

Request Control was also reviewed, but its Firefox listing was last updated in
July 2020 and it requests access to every website. It is not a safer maintained
replacement. NoScript covers script execution but does not provide uMatrix's
general request matrix; it remains a complementary control in this profile.

To enable uBO's documented medium mode:

1. Open the uBlock Origin dashboard and confirm **I am an advanced user** is
   enabled. The declarative policy should already set it.
2. Open **My rules**.
3. Add these global rules under **Temporary rules**:

   ```text
   * * 3p-script block
   * * 3p-frame block
   ```

4. Test normal browsing, use the uBO logger to diagnose a broken site, create
   only the narrow site-local `noop` rules it needs, and then click **Commit**.

Medium mode blocks third-party scripts and frames by default and will break
some sites. NoScript remains installed as requested, so check its policy first
when JavaScript fails, followed by the uBO logger.

## Added isolation and transport controls

Mozilla Multi-Account Containers gives first-party identities explicit
separation beyond Firefox's automatic cross-site storage partitioning. Create
separate containers for at least Personal, Work, Banking, and Shopping, then
assign login sites to the appropriate container. Containers do not replace a
VPN and are disabled in private windows. The extension needs all-sites and
history permissions to route assigned sites, so it is intentionally the only
new privileged browser extension in this change.

Firefox DNS uses Cloudflare's standard, explicitly unfiltered DNS-over-HTTPS
endpoint directly. This deliberately bypasses the local Blocky list so Firefox
remains the recovery browser for a DNS false positive; uBlock Origin still
provides browser-level filtering. The provider's `1.1.1.1 for Families`
endpoints are not used. Plaintext fallback is disabled, while the policy
remains unlocked so a VPN or private network with split DNS can override it.
`localhost`, `.local`, and `home.arpa` bypass browser DoH and use the system
resolver. If other internal names fail while a VPN is active, configure a
narrow routed DNS suffix as documented in `docs/08-networking.md` rather than
adding a broad permanent browser exception.

## Enforced browser policy

The profile enables or enforces:

- Strict Tracking Protection, including suspected fingerprinters, email
  tracking, cryptominers, and known fingerprinting scripts
- Total Cookie Protection and partitioned network state
- resistFingerprinting, letterboxing, and fingerprinting protection
- Global Privacy Control and Do Not Track
- HTTPS-only mode and blocked active/passive mixed content
- unfiltered encrypted DNS with no silent plaintext fallback
- certificate-error and Safe Browsing interstitials that cannot be bypassed
- Safe Browsing for phishing, malware, and downloads
- blocked geolocation, camera, microphone, notification, and autoplay requests
- no form history, payment-card data, address autofill, remote search
  suggestions, speculative connections, prefetching, or hyperlink auditing
- WebRTC local-address mitigation
- telemetry, studies, sponsored content, Firefox Accounts/Sync, Pocket,
  shopping, and Firefox AI surfaces disabled
- downloads staged in a temporary directory until the user chooses to save
  them

Safe Browsing remains enabled because disabling phishing and malware checks is
a material security regression, not a worthwhile privacy improvement.

## Extension selection boundary

No additional canvas blocker, URL cleaner, CDN-localizer, or JavaScript API
spoofing extension was added. Firefox resistFingerprinting, query stripping,
uBO, and Decentraleyes already cover those areas; adding more privileged
extensions would increase uniqueness, breakage, and extension attack surface.
The only new extension is Mozilla's containers add-on because it provides a
separate first-party identity-isolation control.

## Verification after installation

Open these internal pages:

```text
about:policies
about:addons
about:preferences#privacy
```

In `about:policies`, confirm the policies are active and there are no errors.
In `about:addons`, confirm uMatrix is absent and the nine extensions above are
present. In Firefox network settings, confirm DNS over HTTPS uses
`https://cloudflare-dns.com/dns-query`.

Close Firefox fully before applying a rebuild. Managed uBO storage may require
two complete browser restarts after a policy changes.

## Compatibility and persistence

resistFingerprinting and letterboxing can alter timezone reporting, window
sizing, canvas output, and media APIs. NoScript and uBO medium mode will require
site-specific rules for many modern applications.

The profile does not clear all cookies and site data on shutdown. That would
discard normal authenticated sessions and OneTab workflows. Cross-site storage
is partitioned instead; use a private window for an ephemeral session.

DuckDuckGo is the normal and private default search engine. NUR and all add-ons
remain pinned by `flake.lock`; update the lock only as part of a reviewed system
update.

## Primary references

- [uMatrix archived upstream repository](https://github.com/gorhill/uMatrix)
- [uBlock Origin dynamic filtering](https://github.com/gorhill/uBlock/wiki/Dynamic-filtering)
- [uBlock Origin blocking modes](https://github.com/gorhill/uBlock/wiki/Blocking-mode)
- [Request Control Firefox listing](https://addons.mozilla.org/en-US/firefox/addon/requestcontrol/)
- [Mozilla Firefox policy reference](https://mozilla.github.io/policy-templates/)
- [Mozilla Multi-Account Containers](https://support.mozilla.org/en-US/kb/containers)
- [Cloudflare unfiltered resolver and encrypted endpoints](https://developers.cloudflare.com/1.1.1.1/infrastructure/network-operators/)
- [Cloudflare public-resolver privacy commitments](https://developers.cloudflare.com/1.1.1.1/privacy/public-dns-resolver/)
