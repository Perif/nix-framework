# Configure the installation

Complete [source review and installer preparation](prepare.md) first. This
stage edits `settings.nix`; it does not touch the disk. The settings are read
from the reviewed Git-backed source for each later stage.

## Review installation-specific values

Open `settings.nix` and set the final values. Do not replace the whole file with
an excerpt: preserve the existing `power`, `builds`, `storage`, `network`, `ai`,
`display`, `audio`, `qbz`, and other `features` settings.

| Setting | Required action |
| --- | --- |
| `hostname` | Keep `framework-pro` or choose the final hostname. |
| `timeZone` | Select an IANA zone directly, or use the install-time detector below. It remains fixed after installation. |
| `defaultLocale`, `consoleKeyMap` | Keep or replace the regional defaults. |
| `dns.*` | Keep or consistently replace the encrypted upstream and bootstrap addresses. Review the switch, lists, and exceptions in [NETWORKING.md](../NETWORKING.md). |
| `diskDevice` | Replace the rejected sentinel with the verified target NVMe `/dev/disk/by-id/...` path. |
| `user.name`, `user.description` | Set the local login name and displayed name. |
| `user.sshAuthorizedKeys` | Optional. Add only complete public keys you control; an empty list keeps sshd disabled. |
| `features.qbz` | Keep `false` unless you supply a separately maintained package. |
| `features.secureBoot` | Keep `false` for initial installation. Enable only after the [post-install procedure](secure-boot.md). |
| Git name and email | Replace the example identity. |
| Password fields | Prefer both `null`; set the password in the installed target after installation. |

You will choose a separate LUKS passphrase during formatting. Do not store it
in `settings.nix`.

## Identify and set the target drive

Confirm that this is the intended machine, then list whole drives and stable
NVMe identifiers:

```bash
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/product_version
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN
ls -l /dev/disk/by-id/nvme-* | grep -v -- '-part'
```

This build expects the Samsung SSD 990 EVO Plus 2TB (model family
`MZ-V9S2T0`), normally about 1.82 TiB in binary units. Use the exact model-and-
serial link reported on this machine; an `nvme-eui.*` link is not guaranteed.
Set that path in `settings.nix` as `diskDevice`. Do not use a `/dev/nvme0n1`
name that can change between boots.

Inspect the configured target without changing it:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix eval --raw --impure --expr '(import ./settings.nix).diskDevice'
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS /dev/disk/by-id/REPLACE_WITH_THE_EXACT_NVME_LINK
wipefs --no-act /dev/disk/by-id/REPLACE_WITH_THE_EXACT_NVME_LINK
```

Replace the example path with the same stable path saved in `settings.nix`.
Stop if the model, serial, size, resolved device, existing signatures, or
contents do not match the drive you intend to erase. Keep a backup of any data
you may need.

## Choose the timezone

A timezone can be selected directly in `settings.nix`. To detect one from the
installer’s public IP, run the repository helper after reviewing the source:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#detect-timezone
```

It makes one HTTPS request to ipapi.co and writes the returned IANA zone into
`settings.nix`; it does not change the live installer clock. A VPN/proxy or
inaccurate IP geolocation can select the wrong region. Review the result. To
bypass detection or correct it, select an explicit zone:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#detect-timezone -- --timezone Europe/Paris
```

An explicit timezone is preserved by later detection runs. A failed request
leaves the file unchanged; `null` is rejected during evaluation rather than
silently choosing a zone. No location service is enabled on the installed
laptop. After travel, change the setting and rebuild. The Plasma clock should
use **Local**.

List possible values if needed:

```bash
timedatectl list-timezones
locale -a
localectl list-keymaps
```

## Optional declarative password

The preferred path leaves both password values `null`; the account stage sets
the password inside `/mnt` after installation. If a declarative password is
required, generate a yescrypt hash and put the complete result in
`user.hashedPassword`, keeping `initialPassword = null`:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt
```

The hash is still copied into Git history and the world-readable Nix store. Use
a strong unique password and do not publish the repository. Never store a
plaintext password or private key in the configuration.

After all settings edits and timezone detection, review and stage only the
intended configuration change for the Git-backed snapshot:

```bash
cd /tmp/nixos-config
git add settings.nix
git diff --cached --check
git diff --cached
git diff --quiet
git status --short
```

Do not stage the whole working directory as a shortcut. Never stage credentials,
private keys, or other secrets. Confirm `git diff --quiet` exits successfully
and review every staged file shown by `git diff --cached`; the preflight rejects
unstaged tracked changes. New files needed by the configuration must also be
added deliberately. Untracked or ignored files are not included in the
immutable snapshot.

Run the environment and configuration preflight after settings are complete:

```bash
sudo -i
cd /tmp/nixos-config
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#installer -- preflight
```

`preflight` evaluates the reviewed settings, verifies the supported installer
environment, and displays the configured disk identity without partitioning or
formatting it. Stop if any value is wrong. Continue to
[plan and prepare storage](storage.md).
