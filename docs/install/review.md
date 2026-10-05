# Installation adversarial review

Reviewed on 2026-10-04. Scope: the fresh-install stages, their shared helpers,
the existing-system upgrade route, packaging, CI, and installation documentation.
This is a review record, not certification of a physical installation.

## Independent review perspectives

| Model | Review type | Main failure cases examined |
| --- | --- | --- |
| GPT-5.5 | Security and destructive-operation review | Wrong disk, unsafe source, stale state, confirmation bypass, unintended password target. |
| GPT-6 Sol | Reliability and fault injection | Lost shell state, partial failures, changed devices, missing mounts, encrypted storage ancestry, account failure. |
| GPT-6 Luna | Operator and documentation review | Fresh install versus upgrade, copy/paste failure, interrupted sessions, stale checkout, migration recovery. |

The primary implementation pass also exercised real Git/Nix behavior and
checked the Linux utility interfaces. Findings were assessed before changes;
an untracked-file warning was resolved by staging the new files for the flake.

## Findings and changes

| Failure | Resolution |
| --- | --- |
| Separate shell snippets could continue after a failed prerequisite or lose the chosen username. | Independent commands reread configuration, stop on command failure, and use the installed account name with direct command arguments. |
| A shell-selected disk could differ from the evaluated Disko target. | Evaluate the effective target from the same immutable source and require equality. |
| A partition identifier, active mapping, existing `vg`, or occupied mount could reach formatting. | Validate a whole-disk identifier and inspect active descendants, swap, VG names, and mount state before confirmation and again afterward. |
| Source edits or copying an entire checkout could install a different tree or include untracked secrets/history. | Require a reviewed Git index, reject unstaged edits and source symlinks, archive the Git-filtered flake, and copy that snapshot without Git metadata. Tracked secrets remain the operator's responsibility. |
| A retry could silently mix configurations. | Refuse an existing target configuration unless its files match the reviewed snapshot. |
| Correct mount names could conceal a different disk, subvolume, or plaintext PV. | Check mount sources, physical disk identity, Btrfs subvolume roots, exact encrypted LVM ancestry, and active encrypted swap. |
| An absolute target system-profile symlink could appear missing from the live ISO. | Recognize the symlink and validate the account inside the installed target. |
| Tool output assumptions were wrong. | Request an explicit `lsblk` tree; parse documented read-only `swapon` output; archive rather than rely on a potentially unrealized metadata path. |
| Fresh-install, upgrade, and recovery instructions overlapped. | Separate routes and explain which commands are valid after partial installation. Clone and rebuild sequences stop on failures. |

## Evidence and remaining limits

- The synthetic suite contains 24 tests, including fault paths; it passes
  locally and through the packaged Apple Silicon Nix check.
- The real Git/Nix source regression verifies an existing immutable snapshot,
  staged settings, exclusion of ignored/untracked files and Git history, and
  refusal of unstaged edits. It passes locally and is included in CI.
- All flake outputs and the system derivation evaluate with a non-device disk
  identifier and explicit UTC in an isolated validation copy.
- Linux CI runs the synthetic suite, the packaged command's help, actual
  read-only `lsblk`/`findmnt`/`swapon` checks, and the source regression before
  the existing full system build. Consult the PR's checks for the current run.

No review or test here formats a real disk, installs or activates this system,
tests a LUKS password, reboots the laptop, or verifies its hardware. The utility
checks do not prove the final laptop's LVM ancestry. Confirm the actual disk,
layout, login, boot, networking, and hardware through the installation and
first-boot guides. The supported destructive environment is deliberately
limited to the standard NixOS UEFI ISO; unsupported live layouts stop.
