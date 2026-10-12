# Install NixOS

For a **fresh installation** on the Framework Laptop 13 Pro. Back up the target
disk first. Formatting erases it. For an installed system, use
[upgrades](install/upgrade.md); for an interrupted install, use
[recovery](install/recovery.md).

Read the numbered files in `docs/install/` from `01-prepare.md` through
`05-first-boot.md`, in order. The other files are supporting guides for optional
setup, later changes, recovery and repository checks; they are not additional
installation stages. Stop on any failed command or unexpected output.
Commands run in a root shell on the standard NixOS UEFI installer USB until the
first reboot. Each page states its expected result and next step.

| File (in order) | Action | Result before continuing |
| --- | --- | --- |
| `01-prepare.md` | [Prepare USB and review source](install/01-prepare.md) | UEFI, network and reviewed Git revision confirmed |
| `02-configure.md` | [Set machine values](install/02-configure.md) | Exact disk, username and timezone staged; preflight passes |
| `03-storage.md` | [Plan and format storage](install/03-storage.md) | Reviewed identities match; expected mounts verified |
| `04-system.md` | [Install and set password](install/04-system.md) | System installed and login password verified |
| `05-first-boot.md` | [Verify first boot](install/05-first-boot.md) | Login, networking, storage and hardware checks pass |

The default layout is a 1 GiB EFI partition plus LUKS2 → LVM → encrypted
40 GiB swap and Btrfs subvolumes for root, home, Nix, logs, snapshots and Ollama.
TRIM/discard is enabled; it exposes which encrypted SSD blocks are unused.
Review [`hosts/framework-pro/disk.nix`](../hosts/framework-pro/disk.nix) before
installation if that tradeoff does not suit your requirements.

After first boot, use [one change workflow](install/customization.md) for settings
and packages. [Secure Boot](install/secure-boot.md) and
[TPM unlock](FINGERPRINT-TPM.md) are later, separate steps.

## Existing links

<a id="6-evaluate-before-touching-the-disk"></a>
Evaluation before erasure: [configure](install/02-configure.md) then [plan](install/03-storage.md).

<a id="11-first-boot-verification"></a>
Verification: [first boot](install/05-first-boot.md).

<a id="12-customize-dns-shells-and-editors"></a>
Customization: [apply a change](install/customization.md).

<a id="13-enable-signed-secure-boot"></a>
Signed boot: [Secure Boot](install/secure-boot.md).

<a id="14-routine-safe-rebuild-workflow"></a>
<a id="normal-rebuilds"></a>
Rebuilds: [apply a change](install/customization.md).

<a id="one-time-model-storage-migration-for-an-existing-installation"></a>
Older model storage: [one-time Ollama migration](install/ollama-migration.md).
