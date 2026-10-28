# Framework Laptop 13 Pro — NixOS

A modular NixOS configuration for the Intel Framework Laptop 13 Pro: Plasma
Wayland, encrypted Btrfs storage, local AI, development tools, and personal apps.
Set machine-specific values in [`settings.nix`](settings.nix).

## Start here

See the [numbered guide index](docs/README.md) for the complete reading order.

| Task | Follow this guide |
| --- | --- |
| Fresh installation; erases the selected disk | [Install in five stages](docs/00-install.md) |
| Change a setting or add software | [Edit → test → verify → apply](docs/install/06-customization.md) |
| Update an existing installation | [Upgrade](docs/install/26-upgrade.md) |
| Resume an interrupted installation | [Recovery](docs/install/28-recovery.md) |
| Understand or extend the modules | [Architecture and ownership](docs/29-modularity.md) |
| Run repository checks | [Validation](docs/install/30-validation.md) |

For a fresh installation, use a reviewed Git checkout. The installer verifies the
selected disk and requires an exact erase confirmation. The installed
`/etc/nixos` is a writable snapshot without Git history. Never run Disko or the
installer's `format` stage to update an installed system.

## Configure daily use

| Area | Guide |
| --- | --- |
| Software switches, Wine, KeePassXC, direnv, NH, mpv, Open WebUI | [Applications](docs/12-workstation-apps.md) |
| Beyond All Reason and Gamescope | [Gaming](docs/12-workstation-apps.md#beyond-all-reason-and-gamescope) |
| Ollama, Continue, llama.cpp, optional Ollaya | [Local AI](docs/18-local-ai-development.md) |
| REA and configured Ghidra | [Reverse engineering](docs/19-rea.md) |
| Project environments and language tools | [Project template](templates/project/README.md) |
| Editor preferences and extensions | [Editors](docs/13-editors.md) |
| ICC profiles, HDR, AC/battery refresh rates | [Display](docs/09-display.md) |
| EasyEffects, music players, DC-Elite | [Audio](docs/10-audio.md) |
| Touchpad preferences | [Touchpad](docs/11-touchpad.md) |
| Power, build limits, sleep, charging | [Performance](docs/21-performance.md) |
| Measure power, decoding and resume behavior | [Measurements](docs/22-power-measurements.md) |
| DNS, Wi-Fi and WireGuard | [Networking](docs/08-networking.md) |
| Firefox / Chromium / Tor | [Firefox](docs/15-firefox.md), [Chromium](docs/16-chromium-browsers.md), [Tor](docs/17-tor-browser.md) |
| Signed boot and optional TPM unlock | [Secure Boot](docs/install/23-secure-boot.md), [Fingerprint/TPM](docs/24-fingerprint-tpm.md) |
| Security defaults and Git checks | [Security](docs/07-security-privacy.md), [Git safety](docs/14-git-safety.md) |
| Controllers | [Controllers](docs/20-controllers.md) |

Default policy: built-in display HDR is disabled; refresh-rate switching is
opt-in; Ollama, Open WebUI and Ollaya start on demand. Ollama and llama.cpp use
Intel Vulkan; the packaged Ollaya backend uses the CPU. Model weights are
separate downloads. Enable Secure Boot only after a successful normal boot.

CI covers evaluation, Linux builds and selected VM/runtime checks. Panel color,
audio routing, GPU acceleration, touchpad behavior and sleep still need
[verification on the laptop](docs/install/05-first-boot.md).
