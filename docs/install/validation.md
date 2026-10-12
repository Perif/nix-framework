# Validate repository changes

This page covers repository and CI checks. It is not a substitute for the fresh-install, first-boot, or hardware verification paths.

## 1. Prepare a validation copy

Keep the real disk sentinel and timezone defaults unchanged in the repository.
Copy the source to a disposable directory; in that copy only, set
`diskDevice = "/dev/disk/by-id/evaluation-only"` and `timeZone = "UTC"`.
Never run installer stages or Disko on the development host.

## 2. Evaluate every output

From that validation copy:

```bash
nix flake check --no-build --all-systems
```

**Expected:** all outputs evaluate, including full-system feature combinations.
This command does not run the tests or build the Linux system.

## 3. Run native tests

```bash
nix flake check --print-build-logs
```

This builds/runs checks supported by the current host. On x86_64 Linux it includes
VM tests and needs working virtualization. Apple Silicon checks omit Linux-only
runtime tests; use Linux CI for those. See individual checks below to isolate a
failure. Do not bypass a failing required check.

## 4. Check Linux CI and hardware

Require both jobs in `.github/workflows/nix.yml` to pass on the exact revision:
the full Linux system build with helper/runtime checks, and the disposable
installer/recovery/boot VM. Then complete [first-boot verification](05-first-boot.md)
on the laptop. CI cannot establish physical display, battery or resume behavior.

## Check coverage and individual commands

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
mount verification, install ordering, account status, hidden Git index flags,
and rejection of noncanonical storage paths before formatting. The workflow also
runs `nix run .#installer -- --help` as a packaging smoke check.

Separately, `tests/test_installer_linux.py` runs directly on the GitHub runner,
outside the Nix build sandbox. It calls the runner's actual read-only `lsblk`,
`findmnt`, and `swapon` commands and checks their output schemas. It does not
write to devices, mount filesystems, activate swap, format, or install an OS.
Neither check validates this laptop's hardware or proves a physical install.

`tests/test_installer_source.py` uses a disposable Git clone and real Nix
archive operation to verify staged settings and exclusions from the immutable
snapshot. It also checks that unstaged edits and assume-unchanged/skip-worktree flags
stop the operation, using real Git and Nix. The clone
uses a non-device disk identifier; no installer stage is invoked.

The timezone check covers detected and explicit zones, preserved settings, and
lookup failures without making a live geolocation request. Before flake
validation, CI replaces the disk sentinel with a non-device identifier and
sets UTC explicitly. Host-runner checks never invoke an installer stage or
run Disko against the runner's disks. CI evaluates every flake output and builds the default
x86_64-linux system on an Ubuntu runner for pull requests and pushes to `main`.
The workflow pins its GitHub Actions by commit. A green workflow is the full
Linux build check that an ARM macOS development host cannot perform locally.

The `installer-vm` check runs real production installer commands and Disko only
inside a disposable x86_64 QEMU guest with a sparse 80 GiB NVMe image. It tests
preflight/plan, interactive partitioning and LUKS setup, mount verification,
closing and recovering the target after an interrupted installation, preserving
a canary and installation record, `nixos-install`, account password setup,
UEFI boot from the installed disk, interactive unlock and password login.
The guest has a tmpfs live root, a real ISO9660 fixture mount and EFI firmware;
no production live-environment guard is disabled.

```bash
# Linux host with KVM; all writes stay in the disposable VM disk image.
nix build .#checks.x86_64-linux.installer-vm --no-link --print-build-logs
```

The target imports the production Disko layout with a minimal test OS and
test-driver instrumentation. It does not boot the full Plasma/Framework system,
test a downloaded release ISO, or validate hardware, suspend, graphics, audio,
Secure Boot, or physical disk power-loss behavior. The separate full-system
build and the laptop's first-boot checklist remain required.

The `webui-bootstrap` check covers secret-file permissions, input validation,
service startup guards and failure recovery with synthetic fixtures. It never
creates real credentials or modifies a running service on the check host.

The `display-sdr` check exercises the production helper against a stateful
KScreen fixture: internal/external targeting, EDR on SDR-only panels, preserving
ICC/layout/brightness settings, read-only repeated checks, and failed or ignored
changes. It also checks AC/battery mode selection, fractional refresh matching,
unchanged resolution, opt-in refresh without SDR enforcement, and SDR fallback
when UPower fails. Software-profile evaluation covers disabled and enabled
refresh policy independently of the HDR switch.

The `power-settings` Linux check runs the production activation with real
KConfig in a disposable directory. It verifies all three sleep modes, invalid
setting rejection, preserved idle/brightness settings, and profile-hook backup
and restoration. The `power-report` check validates sensor units, charging and
missing-reading behavior, peripheral-battery exclusion and command errors.
CI also builds and smoke-tests the packaged diagnostic CLI.
This does not replace the [physical display checks](../DISPLAY.md#hdr-disabled-on-the-built-in-panel).
