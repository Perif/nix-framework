# Update review — 2026-09-28

**2026-10-05 installer and software follow-up:** Added capacity checks before
erasure, exact EFI partition validation, a contract derived from evaluated
Disko, guarded non-formatting recovery, and a persistent source/disk/layout
record. Upgrade instructions now pause between temporary testing and permanent
activation. A disposable VM test covers the installation/recovery/boot/login
path; check the PR's CI for execution results.

Added selectable development/language/AI/browser/editor/personal-app groups,
project-local development shell templates, Just, ShellCheck, shfmt, fzf,
zoxide, delta, LibreOffice Qt, Thunderbird, KDE Connect and Syncthing. KDE
Connect login autostart and new firewall openings are disabled; Syncthing is
started manually. Restic is excluded. Open WebUI now uses an interactive,
signup-disabled administrator bootstrap with startup verification and credential
cleanup. Its root-snapshot retention is documented. No workload speedup is
claimed without laptop measurements.

**2026-10-04 workstation additions:** Added stable Wine WoW64/Winetricks,
KeePassXC with Firefox integration and documented 1Password 1PUX/passkey migration
limits, direnv/nix-direnv, NH, mpv hardware decoding, and localhost on-demand Open
WebUI sharing Ollama. Build concurrency is configurable with validated optional
`builds.maxJobs`/`cores`; defaults remain unchanged until laptop measurements.
Hyperfine/turbostat and a repeatable contention measurement procedure are
included. Home snapshots are opt-in with short retention. A small offline VM
test now boots the production resolved/Blocky stack and checks resolution,
filtering, allowlists and restart recovery. It exposed a port collision with
multicast DNS, so Blocky and resolved now use loopback port 5335 instead of 5353.

The preceding revision `da5d66b` passed the complete default Linux system build.
The additions pass full flake evaluation locally; their complete Linux build
and DNS VM execution are tracked by the updated PR's CI. No physical hardware
performance result or real password-vault migration is claimed.

**2026-10-04 Firefox build repair:** Linux CI reached the full system build but
failed fetching the removed Bypass Paywalls Clean 4.4.5.3 XPI. The override now
uses the publisher's versioned signed 4.4.5.6 XPI with a fixed content hash,
avoiding the publisher Git host's incomplete-pack failure. Its SHA-256 matches
the publisher's release-hashes.txt, and the XPI manifest and Mozilla signing
metadata were checked. Full package and browser runtime validation are still
required.

**2026-10-04 music applications:** Added qobuz-player 0.9.0 and MusicBrainz
Picard 2.13.3 alongside the existing Strawberry 1.2.18 installation. The
qobuz-player source moved to `SofusA/qobine`; a package override fetches the
same release with the unchanged source and Cargo hashes. A direct download
from the new repository matched the locked hash, and the Linux player package
was successfully retrieved from the Nix binary cache (not rebuilt or run on
this macOS host). Full flake evaluation and the selected Home Manager package
list passed. [Audio setup](AUDIO.md#qobuz-player--qobine) documents explicit
DC-Elite selection and the player's format-fallback limitation; Qobuz login
and physical DAC playback remain untested.

**2026-10-04 availability correction:** QBZ's author
[closed the project and distribution channels](https://github.com/vicrodh/qbz).
The former pinned revision returns 404; the September local evaluations below
used a cached source and did not establish fresh-download availability. The
unavailable flake input is now removed, QBZ defaults to disabled, and an optional
`qbz.packageFile` hook accepts an independently maintained package. Cached
upstream source is not redistributed. CI now evaluates and builds the same
default application configuration.

The corrected default passes full flake evaluation using a fresh download cache
and an isolated Nix store. The `qbz-configuration` check covers missing,
nonexistent and incorrectly typed package paths, plus a supplied package recipe;
it validates the option contract, not QBZ's discontinued application.

Updated the existing release branches; `system.stateVersion` and
`home.stateVersion` remain 26.05.

| Input | Previous revision | New revision |
| --- | --- | --- |
| Nixpkgs, nixos-26.05 | c25784012c99 | cf5e76507c6e |
| Home Manager, release-26.05 | fd0956c99c41 | a6631107a83c |
| nixos-hardware | 44d95795ee2d | 30d48a0ec603 |
| Disko | ff8702b4de27 | 725ea35e410a |
| NUR | 2ce3ccecbaa8 | d7ecc51616e6 |

The September review initially retained QBZ **2.0.2**, revision
`aa5690e4491507976b56a982025eb4b38ec8e064`.
Updating to upstream `fcf6503fd8804c13ebf7d3551b648c8a9cdabbb7` failed because
that source has no `flake.nix`. Fresh-runner CI later proved that the retained
revision is also unavailable; the correction above supersedes that pin.
Lanzaboote remains at the deliberately selected v1.1.0 tag.

## Display and audio

- Added the Notebookcheck MND508ZB1-1 ICC and an override path for a calibration
  of the actual panel. [Selection and verification](DISPLAY.md).
- Added EasyEffects 8.2.4, the Pro-specific FW13SpeakersV2-Loudness preset,
  speaker device/route autoload support, and an empty Flat fallback for
  unmatched outputs. [First-use association](AUDIO.md#easyeffects-speaker-preset).
- Kept the DC-Elite outside PipeWire and EasyEffects through the existing
  WirePlumber exclusion. Microphone streams are not automatically processed.
- Added `audio.speakerPreset` selection: original V2, local EQ/limiter variant,
  bit0fun alternative, Flat, or a custom output JSON. All bundled choices are
  available in the GUI. [Preset comparison](AUDIO.md#choosing-another-preset).
- Added `display.profile` selection: Notebookcheck, native/default mode, or
  custom calibration, plus additional named ICC files for comparison. The
  native choice is not an ICC. Applying or clearing the active profile still
  requires Plasma. [ICC options](DISPLAY.md#profile-options).

## Local AI and AC/battery policy

- Added pinned Ollaya 0.7.5 packaging and an on-demand user service on loopback
  port 11435, with CPU decision models, one loaded model and a bounded queue.
  The release checksum is pinned; the package keeps its matching llama.cpp ABI.
  Intel GPU/NPU acceleration is not supported by this Ollaya integration.
- Centralized Ollama/Continue context and output defaults in `settings.ai`,
  bounded Ollama model/concurrency defaults, and disabled Ollama cloud features.
  Vulkan remains the GPU backend for Ollama and standalone llama.cpp. Added
  `OLLAMA_IGPU_ENABLE=1`: pinned Ollama 0.32.3 otherwise drops integrated Vulkan
  GPUs, so selecting the Vulkan package alone did not admit this Intel GPU.
- Added source-based Plasma profiles: performance on AC, balanced on battery,
  power-saver at low battery. `settings.power` controls the three choices.
  Activation owns those profiles and the aligned sleep/lid actions described
  below, preserving brightness and idle timeouts. Log out/in after activation;
  this policy applies in Plasma.
- Added Intel GPU diagnostics, reproducible benchmark commands, and an Ollaya
  decision API example to [LOCAL-AI-DEVELOPMENT.md](LOCAL-AI-DEVELOPMENT.md).
  [PERFORMANCE.md](PERFORMANCE.md) explains Intel EPP/governor behavior and
  verification of charger transitions.
- NixOS/Home Manager derivations and the full flake evaluation pass after these
  changes. Additional evaluation checks cover alternative AI/power settings,
  disabling Ollaya, on-demand service wiring, and invalid-setting rejection.
  The Ollaya hash matches the release checksum file and GitHub asset digest;
  repeated interrupted downloads prevented complete archive inspection here.
  Ollaya's Linux build, package install checks and actual model inference remain
  target-machine checks; no throughput, battery-life or thermal gain is claimed.

## Applied community-review recommendations

- Select Xe for early graphics initialization and the modern Intel media driver
  only; retain Intel compute/VPL and modern 32-bit media support. No force-probe
  or GPU blacklist is added.
- Align all three Plasma power-source profiles with suspend-then-hibernate for
  lid and power-button actions, with external-monitor lid inhibition retained.
  GUI brightness, auto-suspend action and idle timeouts are preserved; the
  managed sleep mode also applies when auto-suspend action is Sleep.
- Gate GC and Btrfs scrub starts on AC, recording skipped jobs for persistent
  retry every 15 minutes. Existing schedules and scrub cancellation are retained.
  Already-running work is not killed when the charger is unplugged.
- Add `power.chargeLimit = 80`, a checked kernel-interface write at boot/service
  activation. `100` permits full charge; `null` removes management without
  resetting a firmware-persisted threshold.
- Add optional `network.wifiPowerSave`: null preserves the global default,
  false disables power saving, true enables it. Saved connection overrides
  remain authoritative. Default remains null.
- Add `features.thunderbolt`, default false, for Bolt authorization support
  without automatic authorization of unknown devices.

## Validation

- Full NixOS and Home Manager derivations evaluate with QBZ enabled and a
  validation-only disk path. The real installation disk sentinel is unchanged.
- `nix flake check --no-build --all-systems` passed on a temporary copy with
  that validation-only disk value. Upstream QBZ emits non-fatal legacy Xorg
  package-name warnings.
- Evaluated versions: Linux 7.2.8, Plasma 6.6.6, EasyEffects 8.2.4,
  Brave 1.95.104, ungoogled Chromium 154.0.8037.57, QBZ 2.0.2.
- Verified the generated EasyEffects unit, data paths, enabled dconf, and the
  retained DC-Elite exclusion. Checked ICC header/tag bounds, JSON structure,
  effect ordering and upstream file checksums.
- Optional speaker bindings evaluate; incomplete/empty pairs are rejected,
  and autoload filename escaping matches EasyEffects.
- All bundled audio selections, custom audio, all three display modes and
  extra ICC installation evaluate. Invalid selectors, missing required custom
  files and invalid ICC names are rejected. The local EQ variant retains the
  original band values and uses the documented gain/limiter changes. The full
  flake evaluation passed again after these selector additions.
- All nine production Git-security integration tests passed on aarch64-darwin
  with the updated Nixpkgs.
- After the community recommendations, full flake evaluation passed again.
  Checked Xe initrd loading, removal of legacy VA-API, Plasma sleep actions,
  maintenance guards and preserved scrub cancellation. All three Wi-Fi modes,
  disabling AC maintenance/charge management, enabling Bolt and a 100% charge
  limit evaluate; invalid charge limits are rejected.
- The native `checks.aarch64-darwin.power-management` build passed ShellCheck
  and eight tests of the production helpers against simulated power/battery
  interfaces. Tests cover skipped, failed and interrupted maintenance, AC retry,
  charge-limit writes and invalid/unsupported charge-control handling. These
  tests also run in Linux CI; Linux execution was not performed on this host.

This macOS check did not build or activate the x86_64-linux system. It did not
measure color accuracy or speaker response. Run the Linux build/activation
checks in [INSTALL.md](INSTALL.md#normal-rebuilds), then select the ICC
and test speaker/headphone switching. Firmware availability must be checked
on the laptop with `fwupdmgr refresh` and `fwupdmgr get-updates`; no firmware
update was attempted here. Existing fwupd and Framework hardware integration
remain enabled. Verify Xe, suspend/resume/hibernation, charge-limit readback and
AC maintenance behavior on the laptop using [PERFORMANCE.md](PERFORMANCE.md).

## PR preparation — 2026-10-04

The staged PII scan found false positives in upstream audio preset decimal
coefficients. The scanner now excludes digit sequences embedded in decimals,
while retaining detection of compact, spaced, hyphenated and sentence-ending
card candidates. The original preset files and checksums remain unchanged.
All eleven packaged Git-security integration tests pass on aarch64-darwin,
including the two new regression tests; the eight power-helper tests also pass.

## Full-repository review — 2026-10-04

Independent reviews used GPT-6 Sol for power, storage, security and CI, and
GPT-6 Luna for AI, audio, ICC and application settings. The primary review
covered networking, installation, boot configuration and integration; a
separate subagent investigated failed Linux CI checks.

Accepted fixes:

- Remove resolved's dependency on Blocky. Upstream resolved starts before
  `sysinit.target`, while Blocky has ordinary service dependencies and waits
  for networking; ordering resolved after it creates a boot cycle.
- Import Sublime's pinned recipe using Nix path addition, preserving lazy
  source access on fresh runners. Linux CI had failed at the interpolated
  store-path import; it now passes evaluation and reaches the system build.
- Use the supplied Bash path in the chained-hook test fixture so it runs in
  Nix's Linux sandbox, where `/usr/bin/env` is absent.
- Evaluate the actual default application selection in CI. This exposed the
  deleted QBZ source, which the prior QBZ-disabled CI evaluation missed. Remove
  that input and retain only an explicit user-supplied package option. Avoid
  duplicate push/PR runs for feature branches.
- Clarify that installation settings examples are excerpts, preserving the
  additional audio, display, AI, power and optional network settings.

Linux CI passed the nineteen helper/security tests, both scans and evaluation,
then exhausted the hosted runner's disk during the full system build. The
workflow now reclaims unused preinstalled toolchains before installing Nix;
the full build remains a required step and its success is not inferred from
the preceding checks.

A suspected Sublime Python-host mismatch was rejected after checking the
actual locked recipe and its evaluated build phase: it already selects 3.14.
No additional measured tuning is claimed. Reviews found no further concrete
defect in the assigned AI/audio/ICC or power/maintenance areas; physical laptop
behavior and any independently supplied QBZ package still need separate
validation.
