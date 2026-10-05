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
- EasyEffects with a pinned Framework 13 Pro speaker preset and Flat fallback
- Notebookcheck MND508ZB1-1 ICC display profile, ready for selection in Plasma
- exclusive direct-ALSA Strawberry -> iBasso DC-Elite path
- qobuz-player terminal streaming client and MusicBrainz Picard tag editor
- Wine WoW64 / Winetricks, KeePassXC with Firefox integration, and mpv
- direnv / nix-direnv project shells and NH rebuild previews
- on-demand localhost Open WebUI using the existing Ollama service
- PCM through 768 kHz where source + ALSA device support it
- Sublime Text / Sublime Merge
- VSCodium with pinned local-agent, Nix, Python, Go, and Rust extensions
- Vim / Neovim
- Ghostty
- llama.cpp / on-demand loopback-only Ollama Vulkan
- Ollaya decision models on Intel CPU, with an on-demand local user service
- automatic Plasma power profiles: performance on AC, balanced on battery
- rootless Podman
- Home Manager
- hardened Firefox privacy profile with declarative extensions
- hardened Brave with managed uBlock Origin Lite and ungoogled Chromium
- separate Tor Browser with its upstream anonymity protections intact
- loopback-only Blocky filtering over unfiltered encrypted DNS, with an
  unfiltered Firefox recovery path
- NetworkManager WireGuard client support and command-line tools
- randomized network identities and explicit host hardening
- One-time installation timezone detection; GeoClue disabled and NTP clock sync enabled
- Nix-daemon access limited to root and the configured login user
- global staged credential/PII commit checks with local-hook chaining
- adaptive Intel thermal and zram-aware responsiveness tuning
- NVMe SMART monitoring, Btrfs scrub, and retained Snapper root snapshots
- optional user-supplied QBZ package (upstream distribution has closed)

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
│       ├── workstation-apps.nix
│       ├── ai.nix
│       ├── vscodium.nix
│       ├── strawberry.nix
│       ├── music-tools.nix
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
- `timeZone`: starts as `null`; `nix run .#detect-timezone` saves the installation
  zone. Explicit zones are preserved; update and rebuild after travel.
- `defaultLocale`, `consoleKeyMap`: other regional settings
- `dns.providerName`, `dns.servers`, `dns.dohUrl`: one coordinated unfiltered
  encrypted-DNS provider definition
- `dns.bootstrapIps`, `dns.filtering.*`: Blocky's bootstrap, relaxed privacy
  list, local allowlist, and emergency enable/disable switch
- `diskDevice`: verified stable target drive path for destructive Disko setup
- `user.name`, `user.description`: the login user
- `user.hashedPassword` or `user.initialPassword`: optional declarative password
- `user.sshAuthorizedKeys`: sshd is enabled only when this list is non-empty
- `features.qbz`: opt into a separately supplied QBZ package; disabled by default
- `qbz.packageFile`: Nix package expression for that optional integration
- `features.wine` / `features.keepassxc`: installed by default; can be disabled
- `builds.maxJobs` / `builds.cores`: optional measured build limits (`null` keeps defaults)
- `storage.homeSnapshots`: opt-in short-retention home snapshots
- `ai.webui`: on-demand Open WebUI enablement and port; signup is disabled and
  `sudo webui-bootstrap` creates the first administrator privately
- `features.devCore` and `features.languageTools`: common development tools and
  individually selectable C, Python, Go, Rust, Node.js and Nix toolchains
- `features.localAI`, `features.extraBrowsers`, `features.extraEditors`: optional
  application groups; see [software selections](docs/WORKSTATION-APPS.md)
- `features.office`: individual LibreOffice, Thunderbird, KDE Connect and
  Syncthing switches; network applications start manually
- `features.secureBoot`: switch from unsigned systemd-boot to signed Lanzaboote
  only after local key setup
- `display.profile`: `notebookcheck`, `native`, or `custom`; reselect in Plasma
- `display.iccProfile`, `display.extraIccProfiles`: your own calibration and
  optional additional ICCs for comparison; see [display options](docs/DISPLAY.md#profile-options)
- `audio.speakerPreset`, `audio.customPreset`: choose among four bundled
  presets or your own output JSON; see [audio options](docs/AUDIO.md#choosing-another-preset)
- `audio.speakerDevice`, `audio.speakerRoute`: optional exact speaker autoload
  association for EasyEffects; configure both together
- `ai`: local-model context, output and concurrency defaults, plus Ollaya enablement
- `power`: AC/battery profiles, AC-only maintenance starts, and battery charge cap
- `network.wifiPowerSave`: optional Wi-Fi power saving (`null`, `false`, or `true`)
- `features.thunderbolt`: optional Bolt dock authorization (off by default)
- `git.userName`, `git.userEmail`: git identity

See [workstation applications](docs/WORKSTATION-APPS.md) for Windows applications,
1Password migration, project shells, rebuilds, video playback and local AI chat.

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

NixOS hardware, NUR, Disko, Home Manager, and Lanzaboote all follow the
same pinned Nixpkgs revision. This removes redundant package-set evaluations and
prevents those inputs from silently using different library versions.

The 2026-09-28 refresh updates Nixpkgs, Home Manager, nixos-hardware, Disko and
NUR. The 2026-10-04 review removes the unavailable QBZ flake input after its
upstream shutdown; a warm local cache had hidden the missing download. See
[update notes](docs/UPDATES.md).

After activation, follow [display setup](docs/DISPLAY.md) to verify the panel
and select its ICC, and [speaker setup](docs/AUDIO.md#easyeffects-speaker-preset)
to associate the preset with the actual speaker device and route.

Do not routinely change `system.stateVersion` or `home.stateVersion`; those
values represent compatibility state, not the version you are upgrading to.

## Installation

Choose the correct route in [INSTALL.md](INSTALL.md). The
[installation index](docs/INSTALL.md) separates fresh installation into source
review, settings and drive selection, storage, system installation, and
first-boot checks. Existing systems use the
[upgrade guide](docs/install/upgrade.md); they must not run the fresh-install
format stage. Secure Boot and routine customization have separate guides.

### Sublime Text compatibility boundary

The locked Nixpkgs defaults are older than the current stable editor. This
configuration reuses that packaging recipe with a targeted, hash-pinned stable
build 4213 (21 September 2026), without updating the system lock. It substitutes
OpenSSL 3, removes the legacy Python 3.3 plug-in host and standard library, and
explicitly sets `disable_plugin_host_3.3 = true`. Build-time checks reject
OpenSSL 1.1 dependencies in the surviving editor/plugin-host binaries and Python.
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
[migration procedure](docs/install/upgrade.md#one-time-ollama-storage-migration)
before activation; fresh installs create it automatically. SMART warnings
persist across logout and notify the configured Plasma user until acknowledged.
The [first-boot guide](docs/install/first-boot.md) includes the notification
test, and [validation](docs/install/validation.md) describes the production
Git-hook tests and CI scans. DNS now uses HaGeZi Normal + full TIF with a
documented size fallback.

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

The updated complete NixOS/Home Manager derivations evaluated on 2026-10-04
with a validation-only disk value;
`nix flake check --no-build --all-systems` also passed. All eleven production
Git-security integration tests and eight power-helper tests passed on
aarch64-darwin; Linux CI also passed these tests. The evaluated closure
includes Linux 7.2.8, Plasma 6.6.6, EasyEffects 8.2.4, Brave 1.95.104,
ungoogled Chromium 154.0.8037.57. QBZ is disabled by default because its pinned
upstream source is no longer available.

The ICC and speaker-preset files passed structural and checksum checks. No
full Linux system build, activation, display calibration measurement, or
audio hardware test was performed on this ARM macOS host. The checked-in disk
sentinel intentionally prevents installation until replaced with the verified
target's stable by-id path. See [current update notes](docs/UPDATES.md) for the
QBZ availability and remaining laptop checks. CI evaluates and builds the same
default application configuration; a separately supplied QBZ package needs its
own Linux build/runtime validation.

Review the [source and settings](docs/install/prepare.md) before the
[storage plan and format stage](docs/install/storage.md). Repository checks are
in [the validation guide](docs/install/validation.md).

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
flake outputs and builds the default x86_64-linux system for pull requests and
pushes to `main`. This complements local evaluation on non-Linux hosts.

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

QBZ's author [closed the project and distribution channels](https://github.com/vicrodh/qbz).
The old pinned source returns 404 on fresh machines, so it is no longer a flake
input and `features.qbz` defaults to `false`. Existing store copies are not
redistributed by this repository.

If you independently maintain a working package, supply its Nix expression:

```nix
features.qbz = true;
qbz.packageFile = ./pkgs/qbz-local.nix;
```

That example path must exist and return a derivation through `pkgs.callPackage`.
Pin and verify the package's sources yourself; setting the flag alone is
rejected. Strawberry remains installed for local direct-ALSA playback.

For the DC-Elite, use QBZ's `ALSA Direct` backend and select the DC-Elite
hardware device. See `docs/AUDIO.md`.
