# 2. Configure the machine

Complete [preparation](01-prepare.md). Stay in the root shell at `/tmp/nixos-config`.
Edit existing fields in `settings.nix`; do not replace whole blocks with excerpts.

1. Identify the whole target disk and its stable path:

```bash
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN
ls -l /dev/disk/by-id/nvme-* | grep -v -- '-part'
```

The intended build uses a Samsung 990 EVO Plus 2 TB (about 1.82 TiB). Match the
model, serial and size to the drive you intend to erase. Use its whole-disk
`/dev/disk/by-id/...` link, never a `-partN` link or `/dev/nvme0n1`.

2. Open the settings:

```bash
nano settings.nix
```

| Field | Set it to |
| --- | --- |
| `diskDevice` | The exact verified whole-disk by-id path; replace the sentinel |
| `hostname` | Your final hostname, or keep `framework-pro` |
| `user.name`, `user.description` | Your login and display name |
| `git.userName`, `git.userEmail` | Your Git identity |
| `defaultLocale`, `consoleKeyMap` | Your locale and keyboard layout |
| `user.initialPassword`, `user.hashedPassword` | Keep both `null`; set the login password after installation |
| `features.secureBoot`, `features.qbz` | Keep `false` for the recommended initial installation |

Leave other defaults unless you need a specific change. Optional software
switches are listed in [Applications](../WORKSTATION-APPS.md).
The LUKS passphrase is separate and is entered during formatting.

3. Detect the timezone from the installer's public IP:

```bash
nix run .#detect-timezone
```

Review `timeZone` in `settings.nix`. A VPN or inaccurate geolocation can select
the wrong region. To correct it without a location request, replace the zone:

```bash
nix run .#detect-timezone -- --timezone Europe/Paris
```

**Expected:** a non-null IANA zone. Detection makes one HTTPS request to ipapi.co;
the installed laptop keeps this zone until you change it.

4. Inspect the exact path you entered (replace the placeholder):

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS /dev/disk/by-id/EXACT_NVME_LINK
wipefs --no-act /dev/disk/by-id/EXACT_NVME_LINK
```

Stop if the disk identity, existing contents or backup do not match your intent.

5. Stage and review the settings. Add any needed custom source files explicitly;
   do not use `git add .`.

```bash
git add settings.nix
git diff --cached --check
git diff --cached
git diff --quiet
git status --short
```

**Expected:** only intended staged files; `git diff --quiet` succeeds, so
the ordinary unstaged diff is empty. Preflight also rejects Git index flags
that can hide tracked edits. No credentials belong in these files.

6. Check the configuration and installer environment:

```bash
nix run .#installer -- preflight
```

**Expected:** successful evaluation and the intended disk identity. This stage
does not format anything. Resolve errors before continuing.

**Next:** [3. Plan and format](03-storage.md).
