# Validate repository changes

This page covers repository and CI checks. It is not a substitute for the fresh-install, first-boot, or hardware verification paths.

Run the packaged production-hook integration tests locally (this builds and
runs tests, unlike `nix flake check --no-build`):

```bash
# On the NixOS laptop:
nix build .#checks.x86_64-linux.git-security --no-link --print-build-logs
# On an Apple Silicon development host:
nix build .#checks.aarch64-darwin.git-security --no-link --print-build-logs
```

The tests use disposable repositories and synthetic data. They cover staged
credentials/PII, redacted diagnostics, unusual filenames, staged versus
unstaged changes, reviewed exclusions, Git errors, and chained local hooks.
CI also scans fetched Git history with Gitleaks and scans a disposable staged
copy of the current committed tree with the PII scanner. High-confidence PII
blocks; lower-confidence findings remain review warnings. Binary content and
all forms of PII are not covered. CI runs after upload, so local hooks remain
the pre-upload protection. No workflow success is implied until it runs on
your repository host.

`.github/workflows/nix.yml` runs several installer checks on x86_64 Linux.
The packaged `installer` check executes unit tests with synthetic command
results and devices, covering source/index guards, target safety, confirmation,
mount verification, install ordering, and account status. The workflow also
runs `nix run .#installer -- --help` as a packaging smoke check.

Separately, `tests/test_installer_linux.py` runs directly on the GitHub runner,
outside the Nix build sandbox. It calls the runner's actual read-only `lsblk`,
`findmnt`, and `swapon` commands and checks their output schemas. It does not
write to devices, mount filesystems, activate swap, format, or install an OS.
Neither check validates this laptop's hardware or proves a physical install.

`tests/test_installer_source.py` uses a disposable Git clone and real Nix
archive operation to verify staged settings and exclusions from the immutable
snapshot. It also checks that unstaged edits stop the operation. The clone
uses a non-device disk identifier; no installer stage is invoked.

The timezone check covers detected and explicit zones, preserved settings, and
lookup failures without making a live geolocation request. Before flake
validation, CI replaces the disk sentinel with a non-device identifier and
sets UTC explicitly. The validation job never invokes an installer stage or
runs Disko. It then evaluates every flake output and builds the default
x86_64-linux system on an Ubuntu runner for pull requests and pushes to `main`.
The workflow pins its GitHub Actions by commit. A green workflow is the full
Linux build check that an ARM macOS development host cannot perform locally.
