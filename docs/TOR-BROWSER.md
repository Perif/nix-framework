# Tor Browser

Tor Browser is installed declaratively from the pinned Nixpkgs package. It
contains Tor Project's browser patches and its own Tor client. This build does
not run a separate background Tor proxy and does not send ordinary Firefox
through Tor.

## Start and verify

Launch **Tor Browser** from Plasma, or run:

```bash
tor-browser
```

On the first screen, select **Connect**. Then visit:

```text
https://check.torproject.org/
```

Use Tor Browser for the session that needs Tor. Closing it ends that browser
session; it is not a system-wide VPN.

## Keep the shared anonymity profile intact

Do not install uBlock Origin, the normal Firefox extensions, custom themes, or
other add-ons in Tor Browser. Do not copy `home/modules/firefox.nix` preferences
into it. Tor Browser's value comes partly from looking like other Tor Browser
users; unique extensions and settings make that harder.

Use the built-in security level instead:

- **Standard** preserves the widest site compatibility.
- **Safer** disables selected risky web features and may break some sites.
- **Safest** disables more active content and will break many sites.

Choose the higher level for a high-risk session, not as an untested global
customization in this repository.

## Identity and download boundaries

- Logging into a personal account identifies that session to the service even
  though Tor hides the network address.
- Use HTTPS and check the destination name. Tor protects traffic inside the Tor
  network, not an unencrypted final connection.
- Do not torrent over Tor.
- Do not open a downloaded document in an external application while online;
  it can make a direct non-Tor connection. Use Tor Browser's built-in PDF viewer
  where practical.
- Do not resize or heavily customize the window solely to appear unique.

## If Tor is blocked

Use Tor Browser's built-in **Connection Assist** or **Configure Connection**
flow and request a bridge there. Bridges are intentionally not pinned in this
public configuration because bridge addresses change and publishing a private
bridge defeats its purpose.

## Updates

The package lives in the immutable Nix store, so update it through the reviewed
flake workflow rather than relying on an in-browser application update:

Follow [update pinned dependencies](UPDATES.md), then complete the separate
verification and promotion steps in the common change workflow.

Tor Browser is security-sensitive. Do not defer a release that fixes a browser
or Tor vulnerability; review the lock change and rebuild promptly.

## Primary references

- [Why Tor Browser differs from Firefox](https://support.torproject.org/tor-browser/getting-started/about-tor-browser/)
- [Tor Browser safe-use guidance](https://support.torproject.org/tor-browser/security/using-tb-safely/)
- [Tor Browser extensions and fingerprinting](https://support.torproject.org/tor-browser/features/plugins/)
- [Tor Browser security levels](https://support.torproject.org/tor-browser/features/security-levels/)
- [Tor Browser connection and censorship](https://tb-manual.torproject.org/circumvention/)
