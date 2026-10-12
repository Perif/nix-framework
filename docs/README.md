# Documentation reading order

The numbers form one reading order across this folder, `install/` and `reference/`.
**Fresh installation:** read 00, then complete 01–05 in order. Stop if a stage fails.
After first boot, select only the later guides you need. Their numbers organize
reading; optional setup, maintenance and recovery are not required install stages.

For an interrupted installation, go directly to [28. Recovery](install/28-recovery.md).
For changes to an installed system, start with [06. Apply a change](install/06-customization.md).

## Fresh installation

| File | Use it to |
| --- | --- |
| [00-install.md](00-install.md) | Start a fresh installation |
| [01-prepare.md](install/01-prepare.md) | Prepare the USB and review the source |
| [02-configure.md](install/02-configure.md) | Set the disk, account and timezone |
| [03-storage.md](install/03-storage.md) | Review and format fresh-install storage |
| [04-system.md](install/04-system.md) | Install the system and set the password |
| [05-first-boot.md](install/05-first-boot.md) | Verify the installed laptop |

## Everyday configuration

| File | Use it to |
| --- | --- |
| [06-customization.md](install/06-customization.md) | Apply subsequent settings or package changes |
| [07-security-privacy.md](07-security-privacy.md) | Understand security defaults and credentials |
| [08-networking.md](08-networking.md) | Configure DNS, Wi-Fi and VPN access |
| [09-display.md](09-display.md) | Set panel color, HDR and refresh policy |
| [10-audio.md](10-audio.md) | Set speaker EQ and direct DAC playback |
| [11-touchpad.md](11-touchpad.md) | Choose touchpad behavior |
| [12-workstation-apps.md](12-workstation-apps.md) | Select and initialize everyday applications |
| [13-editors.md](13-editors.md) | Configure editors |
| [14-git-safety.md](14-git-safety.md) | Set up safe Git commits |
| [15-firefox.md](15-firefox.md) | Configure Firefox |
| [16-chromium-browsers.md](16-chromium-browsers.md) | Configure optional Chromium browsers |
| [17-tor-browser.md](17-tor-browser.md) | Use Tor Browser when needed |

## AI and peripherals

| File | Use it to |
| --- | --- |
| [18-local-ai-development.md](18-local-ai-development.md) | Set up local models and Continue |
| [19-rea.md](19-rea.md) | Use REA and Ghidra |
| [20-controllers.md](20-controllers.md) | Pair and configure a game controller |

## Power and optional boot security

| File | Use it to |
| --- | --- |
| [21-performance.md](21-performance.md) | Choose power and build policies |
| [22-power-measurements.md](22-power-measurements.md) | Measure battery, decoding and sleep behavior |
| [23-secure-boot.md](install/23-secure-boot.md) | Optionally enable signed boot after verification |
| [24-fingerprint-tpm.md](24-fingerprint-tpm.md) | Optionally configure fingerprint and TPM unlock |

## Maintenance and recovery

| File | Use it to |
| --- | --- |
| [25-ollama-migration.md](install/25-ollama-migration.md) | Migrate older model storage only if applicable |
| [26-upgrade.md](install/26-upgrade.md) | Update an existing installation from the repository |
| [27-updates.md](27-updates.md) | Update pinned dependencies |
| [28-recovery.md](install/28-recovery.md) | Resume an interrupted installation without formatting |

## Architecture, verification and historical reference

| File | Use it to |
| --- | --- |
| [29-modularity.md](29-modularity.md) | Understand configuration ownership and extend modules |
| [30-validation.md](install/30-validation.md) | Run repository and CI checks |
| [31-first-boot-checks.md](reference/31-first-boot-checks.md) | Run extended hardware checks |
| [32-ai-backends.md](reference/32-ai-backends.md) | Verify AI backends and measure inference |
| [33-performance-design.md](reference/33-performance-design.md) | Read performance implementation details |
| [34-installation-review.md](reference/34-installation-review.md) | Read the historical installation review |
| [35-update-history.md](reference/35-update-history.md) | Read historical changes and validation limits |

Other entry points: [project development template](../templates/project/README.md),
[profile sources](../assets/README.md) and
[bundled extension provenance](../pkgs/bypass-paywalls-clean/PROVENANCE.md).
README files and package provenance keep their conventional names.
