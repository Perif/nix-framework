# Framework Laptop 13 Pro NixOS

Target:

- Framework Laptop 13 Pro
- Intel Core Ultra Series 3
- 32 GiB RAM
- 2 TB NVMe
- KDE Plasma 6 / Wayland
- LUKS2
- staged signed Secure Boot with Lanzaboote
- encrypted 40 GiB swap
- suspend -> hibernate after 60 minutes
- fingerprint authentication for login and session unlock; password-only sudo
- declarative five-minute Plasma auto-lock and immediate lock after resume
- PipeWire desktop audio
- exclusive direct-ALSA Strawberry -> iBasso DC-Elite path
- PCM through 768 kHz where source + ALSA device support it
- Sublime Text / Sublime Merge
- VSCodium with pinned local-agent, Nix, Python, Go, and Rust extensions
- Vim / Neovim
- Ghostty
- llama.cpp / on-demand loopback-only Ollama Vulkan
- rootless Podman
- Home Manager
- hardened Firefox privacy profile with declarative extensions
- hardened Brave with managed uBlock Origin Lite and ungoogled Chromium
- separate Tor Browser with its upstream anonymity protections intact
- loopback-only Blocky filtering over unfiltered encrypted DNS, with an
  unfiltered Firefox recovery path
- NetworkManager WireGuard client support and command-line tools
- randomized network identities and explicit host hardening
- GeoClue disabled with an explicit time zone and automatic NTP clock sync
- Nix-daemon access limited to root and the configured login user
- global staged credential/PII commit checks with local-hook chaining
- adaptive Intel thermal and zram-aware responsiveness tuning
- NVMe SMART monitoring, Btrfs scrub, and retained Snapper root snapshots
- QBZ / Qobuz native client with direct-ALSA support

## Repository

```text
.
├── flake.nix
├── INSTALL.md
├── settings.nix
├── hosts/
│   └── framework-pro/
│       ├── default.nix
│       └── disk.nix
├── modules/
│   └── nixos/
│       ├── base.nix
│       ├── dns-filter.nix
│       ├── desktop.nix
│       ├── power.nix
│       ├── performance.nix
│       ├── security.nix
│       ├── secure-boot.nix
│       ├── storage.nix
│       ├── audio.nix
│       ├── ai.nix
│       ├── browsers.nix
│       └── containers.nix
├── home/
│   ├── user/
│   │   └── default.nix
│   └── modules/
│       ├── firefox.nix
│       ├── browsers.nix
│       ├── privacy.nix
│       ├── plasma-security.nix
│       ├── ghostty.nix
│       ├── vim.nix
│       ├── sublime.nix
│       ├── git.nix
│       ├── zsh.nix
│       ├── dev-tools.nix
│       ├── ai.nix
│       ├── vscodium.nix
│       ├── strawberry.nix
│       ├── qbz.nix
│       └── dc-elite.nix
└── docs/
    ├── INSTALL.md
    ├── AUDIO.md
    ├── CHROMIUM-BROWSERS.md
    ├── FIREFOX.md
    ├── FINGERPRINT-TPM.md
    ├── GIT-SAFETY.md
    ├── NETWORKING.md
    ├── LOCAL-AI-DEVELOPMENT.md
    ├── PERFORMANCE.md
    ├── SECURITY-PRIVACY.md
    ├── TOR-BROWSER.md
    └── MODULARITY.md
```

## Parameters

`settings.nix` holds installation-specific values. `flake.nix` passes it to
every NixOS and Home Manager module as the `settings` argument, so nothing else
needs editing when these change:

- `hostname`: `networking.hostName` and the flake output name
- `timeZone`: the IANA zone used by the system and Plasma; update it and rebuild
  after travel because automatic location detection is disabled
- `defaultLocale`, `consoleKeyMap`: other regional settings
- `dns.providerName`, `dns.servers`, `dns.dohUrl`: one coordinated unfiltered
  encrypted-DNS provider definition
- `dns.bootstrapIps`, `dns.filtering.*`: Blocky's bootstrap, relaxed privacy
  list, local allowlist, and emergency enable/disable switch
- `diskDevice`: verified stable target drive path for destructive Disko setup
- `user.name`, `user.description`: the login user
- `user.hashedPassword` or `user.initialPassword`: optional declarative password
- `user.sshAuthorizedKeys`: sshd is enabled only when this list is non-empty
- `features.qbz`: include or defer the resource-intensive QBZ build
- `features.secureBoot`: switch from unsigned systemd-boot to signed Lanzaboote
  only after local key setup
- `git.userName`, `git.userEmail`: git identity

### Password

A NixOS user with no password option is initially locked. The recommended
installation leaves both checked-in values `null`, runs `nixos-install`, and
then sets the password directly in the installed system before rebooting:

```bash
nixos-enter --root /mnt -c 'passwd py'
```

This avoids committing plaintext or a reusable password hash. See the complete
installation guide for the alternative declarative-hash path.

## Versioning approach

The flake pins NixOS and Home Manager to the 26.05 release branches instead of
following unstable/master for the entire userspace.

The host explicitly selects `linuxPackages_latest` because this machine benefits
from a recent kernel.

Keep the existing `flake.lock` in source control. It makes input revisions
reproducible; update it deliberately after reviewing upstream changes.

NixOS hardware, NUR, QBZ, Disko, Home Manager, and Lanzaboote all follow the
same pinned Nixpkgs revision. This removes redundant package-set evaluations and
prevents those inputs from silently using different library versions.

Do not routinely change `system.stateVersion` or `home.stateVersion`; those
values represent compatibility state, not the version you are upgrading to.

## Installation

Start with [INSTALL.md](INSTALL.md), then follow the canonical detailed
[docs/INSTALL.md](docs/INSTALL.md) from start to finish. It includes:

- UEFI, network, and installer preparation
- exact `settings.nix` fields to replace
- repeated NVMe model/serial/by-id verification
- pre-destructive Nix and Disko evaluation
- LUKS, LVM, Btrfs, swap, and mount verification
- installation with a password that never enters the flake
- first-boot firmware, fingerprint, session-lock, hibernation, graphics, and
  audio checks
- network-randomization, snapshot, scrub, firewall, and timer verification
- Blocky, encrypted DNS, Tor Browser, and WireGuard client verification
- Brave, ungoogled Chromium, uBlock Origin Lite, the editor/language toolchain,
  VSCodium, and local-AI verification
- Git credential/PII hook verification
- thermal, power-profile, compressed-memory, and hardware-acceleration checks
- post-install Framework Secure Boot key creation, signing, and enrollment
- a lighter first-install path that defers QBZ compilation

Do not copy the Disko command out of context. It erases the configured drive.

### Sublime Text compatibility boundary

Nixpkgs' regular Sublime Text build 4200 still links both plug-in hosts to
end-of-life OpenSSL 1.1. This configuration instead pins build 4205, substitutes
OpenSSL 3, and removes the legacy Python 3.3 plug-in host and standard library.
The editor and Python 3.14 plug-in host remain available without permitting an
insecure Nix package. A plug-in that explicitly requires the old 3.3 host will
fail to load and should be upgraded or replaced.

The managed Sublime installation list contains Package Control,
EditorConfig, LSP, and the syntax-only Nix package. Language servers come from
the pinned Nix closure rather than plug-ins that download private binaries.
Package Control code is not part of the Nix generation; it is the documented
residual reproducibility boundary and updates this minimal set once per day.
This is not an enforced allowlist: manual installs remain possible and live
updates run with your user privileges. Validate the editor and each plugin on
Linux; a successful Nix evaluation does not establish runtime compatibility.

### Storage and security follow-up

Both boot modes retain three EFI generations; check `/boot` space around
kernel updates. Ollama state now uses a separate Btrfs subvolume, outside root
snapshots. Existing installs must follow the
[migration procedure](docs/INSTALL.md#one-time-model-storage-migration-for-an-existing-installation)
before activation; fresh Disko installs create it automatically. SMART warnings
persist across logout and notify the configured Plasma user until acknowledged.
The [installation guide](docs/INSTALL.md) includes the notification test and
the production Git-hook test commands. CI adds credential-history and PII-tree
scans. DNS now uses HaGeZi Normal + full TIF with a documented size fallback.

## Rebuild

Xbox Elite Series 2 support is included through xpadneo (Bluetooth) and xpad
(USB-C). Bluetooth remains off at boot. See the
[controller setup guide](docs/CONTROLLERS.md) for pairing, supported features,
and limitations. The proprietary Xbox Wireless adapter is not enabled.

When stored in `/etc/nixos`:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#framework-pro
```

The `rebuild` and `nix-switch` Zsh aliases do the same with the hostname from
`settings.nix`. Read-only inspection, update, dry-build, temporary activation,
boot-only activation, generation, search, and dependency aliases are listed in
the installation guide.

## Validation status

The complete NixOS/Home Manager derivation passed
`nix flake check --no-build --all-systems` with Nix 2.35.2 on 2026-09-08 using a validation-only disk value
and QBZ enabled. The exact generated DNS YAML also passed the pinned Blocky
0.29.0 parser, and all generated Sublime settings passed JSON parsing. No full
Linux system or QBZ build was run on this ARM macOS validation host. The
checked-in disk sentinel intentionally makes normal evaluation fail until it is
replaced with the installation target's stable by-id path.

The evaluated closure includes VSCodium 1.116.02821, Brave 1.94.117, ungoogled
Chromium 152.0.7977.82, twelve immutable VSCodium extensions, both loopback
model providers, managed Vim/VSCodium/Sublime settings, Blocky, the configured-
user Plasma lock policy, the password-only sudo/fingerprint-unlock PAM split,
and an Ollama unit without a boot target. Runtime desktop, service, DNS, editor,
and browser behavior still needs first-boot verification on the x86_64-linux
laptop.

Run the validation section in `docs/INSTALL.md` before the destructive step.

## Performance

The build adds adaptive Intel thermal management, zram-aware VM behavior, and
background Nix scheduling that favors interactive desktop and audio work. It
also bounds Ghostty memory and excludes dependency/build trees from editor file
watchers. It does not disable CPU security mitigations, force experimental
schedulers, or keep the machine in performance mode on battery.
Rationale, tradeoffs, one-command performance-profile use, and verification are
in [docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Firefox privacy

See:

```text
docs/FIREFOX.md
```

The Firefox module installs the privacy extension stack through NUR and applies
an aggressive profile/policy configuration. Archived uMatrix is replaced by
uBlock Origin's maintained dynamic filtering, and Mozilla Multi-Account
Containers supplies explicit first-party identity isolation. NUR and the
add-ons are pinned by `flake.lock`.

System and network controls, tradeoffs, and verification commands are in
[docs/SECURITY-PRIVACY.md](docs/SECURITY-PRIVACY.md).

Blocky, encrypted DNS, the unfiltered recovery path, and UniFi WireGuard setup are in
[docs/NETWORKING.md](docs/NETWORKING.md). Tor Browser use and its important
anti-fingerprinting boundary are in [docs/TOR-BROWSER.md](docs/TOR-BROWSER.md).

Brave and ungoogled Chromium use a shared managed privacy policy. Brave alone
retains Google-backed Safe Browsing and managed uBlock Origin Lite; ungoogled
Chromium removes Google web-service integration. The security-update and
tracker-blocking boundary is documented in
[docs/CHROMIUM-BROWSERS.md](docs/CHROMIUM-BROWSERS.md).

VSCodium, its immutable Nix/Python/Go/Rust extension set, and the local-only
Continue profiles for Ollama and llama.cpp are documented step by step in
[docs/LOCAL-AI-DEVELOPMENT.md](docs/LOCAL-AI-DEVELOPMENT.md).

Git defaults, staged credential/PII checks, false-positive handling, and the
client-side enforcement boundary are in
[docs/GIT-SAFETY.md](docs/GIT-SAFETY.md).

## Linux build verification

The pinned GitHub Actions workflow in `.github/workflows/nix.yml` evaluates all
flake outputs and builds the complete QBZ-deferred x86_64-linux system on every
push and pull request. This complements local evaluation on non-Linux hosts.

## Zsh

`home/modules/zsh.nix` owns the requested shell history, explicit Nix workflow
aliases, shell options, locale exports, yt-dlp helper alias, and custom two-line
prompt.

Starship is intentionally disabled because it would override the custom Zsh
`PROMPT`. `yt-dlp` is installed because the configured download alias depends
on it.

## Containers

Podman is a NixOS service (`modules/nixos/containers.nix`) because rootless
containers need the setuid `newuidmap` wrapper and subordinate UID ranges that
a Home Manager package cannot provide. `podman-compose` stays in Home Manager.

## QBZ

QBZ is installed from:

```text
github:vicrodh/qbz
```

rather than from the release-branch nixpkgs package. The project documents its
flake as the freshest Nix packaging path. `flake.lock` pins the exact revision
used by this system. `settings.features.qbz` allows its expensive source build
to be deferred until after the first boot.

For the DC-Elite, use QBZ's `ALSA Direct` backend and select the DC-Elite
hardware device. See `docs/AUDIO.md`.
