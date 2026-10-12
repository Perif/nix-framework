# Framework Laptop 13 Pro — NixOS

A modular NixOS configuration for the Intel Framework Laptop 13 Pro: Plasma
Wayland, encrypted Btrfs storage, local AI, development tools, and personal apps.
Set machine-specific values in [`settings.nix`](settings.nix).

## Start here

| Task | Follow this guide |
| --- | --- |
| Fresh installation; erases the selected disk | [Install in five stages](docs/INSTALL.md) |
| Change a setting or add software | [Edit → test → verify → apply](docs/install/customization.md) |
| Update an existing installation | [Upgrade](docs/install/upgrade.md) |
| Resume an interrupted installation | [Recovery](docs/install/recovery.md) |
| Understand or extend the modules | [Architecture and ownership](docs/MODULARITY.md) |
| Run repository checks | [Validation](docs/install/validation.md) |

For a fresh installation, use a reviewed Git checkout. The installer verifies the
selected disk and requires an exact erase confirmation. The installed
`/etc/nixos` is a writable snapshot without Git history. Never run Disko or the
installer's `format` stage to update an installed system.

## Configure daily use

| Area | Guide |
| --- | --- |
| Software switches, Wine, KeePassXC, direnv, NH, mpv, Open WebUI | [Applications](docs/WORKSTATION-APPS.md) |
| Ollama, Continue, llama.cpp, optional Ollaya | [Local AI](docs/LOCAL-AI-DEVELOPMENT.md) |
| REA and configured Ghidra | [Reverse engineering](docs/REA.md) |
| Project environments and language tools | [Project template](templates/project/README.md) |
| Editor preferences and extensions | [Editors](docs/EDITORS.md) |
| ICC profiles, HDR, AC/battery refresh rates | [Display](docs/DISPLAY.md) |
| EasyEffects, music players, DC-Elite | [Audio](docs/AUDIO.md) |
| Touchpad preferences | [Touchpad](docs/TOUCHPAD.md) |
| Power, build limits, sleep, charging | [Performance](docs/PERFORMANCE.md) |
| Measure power, decoding and resume behavior | [Measurements](docs/POWER-MEASUREMENTS.md) |
| DNS, Wi-Fi and WireGuard | [Networking](docs/NETWORKING.md) |
| Firefox / Chromium / Tor | [Firefox](docs/FIREFOX.md), [Chromium](docs/CHROMIUM-BROWSERS.md), [Tor](docs/TOR-BROWSER.md) |
| Signed boot and optional TPM unlock | [Secure Boot](docs/install/secure-boot.md), [Fingerprint/TPM](docs/FINGERPRINT-TPM.md) |
| Security defaults and Git checks | [Security](docs/SECURITY-PRIVACY.md), [Git safety](docs/GIT-SAFETY.md) |
| Controllers | [Controllers](docs/CONTROLLERS.md) |

Default policy: built-in display HDR is disabled; refresh-rate switching is
opt-in; Ollama, Open WebUI and Ollaya start on demand. Ollama and llama.cpp use
Intel Vulkan; the packaged Ollaya backend uses the CPU. Model weights are
separate downloads. Enable Secure Boot only after a successful normal boot.

CI covers evaluation, Linux builds and selected VM/runtime checks. Panel color,
audio routing, GPU acceleration, touchpad behavior and sleep still need
[verification on the laptop](docs/install/05-first-boot.md).
