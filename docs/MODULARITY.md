# Configuration boundaries

The repository deliberately separates concerns.

## Parameters

`settings.nix`

Contains installation-specific values: hostname, locale, time zone, destructive
disk target, login user, optional declarative password, SSH keys, feature flags
and git identity. It also owns the encrypted-DNS provider, Blocky enable switch,
privacy-list URL, and allowlist. `flake.nix` passes it to every module as
`settings`, so modules do not hardcode these machine/user choices.

## Host

`hosts/framework-pro/`

Contains only machine-specific composition and storage:

- module imports
- 2 TB NVMe layout
- LUKS2
- encrypted 40 GiB swap
- Btrfs
- state version

## NixOS modules

`modules/nixos/`

Contains privileged/system behavior:

- base OS / firmware / login user / sshd / network identity defaults
- loopback-only Blocky filtering, system-wide encrypted DNS, and WireGuard
  client tools
- unsigned-to-signed boot ownership and Lanzaboote staging
- Btrfs scrub, Snapper retention and Nix-store maintenance
- Plasma / graphics / Bluetooth / location-service policy
- power and hibernation
- sustained thermal, compressed-memory, and Nix-build responsiveness tuning
- fprintd / PAM / kernel and network hardening
- PipeWire / WirePlumber
- hardened, manually started Ollama daemon
- rootless Podman plumbing

These should not live in Home Manager because they change services, hardware,
boot, PAM, setuid wrappers or system policy.

## Home Manager

`home/user/` composes small reusable modules from `home/modules/`.

One module is used for an application when it has meaningful configuration:

- Firefox
- Tor Browser package boundary
- Plasma session-lock policy
- Ghostty
- Vim
- Sublime Text / Sublime Merge
- VSCodium and its immutable development extension profile
- Git defaults, Gitleaks, and the staged PII hook
- Zsh
- Strawberry
- optional user-supplied QBZ package (disabled by default)
- DC-Elite helper
- AI CLI/runtime packages

Small unconfigured development binaries are intentionally grouped in
`dev-tools.nix`; qobuz-player and MusicBrainz Picard are grouped in
`music-tools.nix`. A one-file-per-package scheme would add structure without
improving ownership or reuse.

## Package ownership

Packages are installed at the narrowest appropriate scope:

- system-rescue and hardware diagnostics -> NixOS
- user applications and developer CLI tools -> Home Manager
- on-demand Ollama daemon -> NixOS service without a boot target
- Ollama user CLI (same package as the service) + llama.cpp -> Home Manager
- Podman -> NixOS service; podman-compose -> Home Manager
- git-lfs -> programs.git.lfs in Home Manager, so the filter config is wired
- Gitleaks and the staged PII scanner -> the Home Manager Git module, so the
  tools and managed pre-commit hook are installed together

This avoids a large duplicated `environment.systemPackages` list.
