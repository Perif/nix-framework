# Fingerprint / LUKS2 / TPM2

## Fingerprint

Enroll after boot:

```bash
fprintd-enroll
fprintd-verify
```

Intended use:

- SDDM login
- Plasma lock screen
- unlock after suspend

Password remains the fallback for login and session unlock. `sudo` is
intentionally password-only so possession of an enrolled finger is not enough
to authorize privileged commands.

The configured Home Manager user owns a declarative Plasma policy in
`home/modules/plasma-security.nix`: the session locks after five minutes of
inactivity, requires authentication immediately when that lock engages, and
locks on resume. Verify all boundaries after enrolling:

```bash
loginctl lock-session
sudo -k
sudo -v
```

Unlock the first command with the enrolled fingerprint. The final command must
request the account password rather than offering fingerprint authentication.
Then leave the session idle for at least five minutes and confirm that it locks.
Finally suspend and resume once and confirm that Plasma presents the lock screen
immediately.

`fprintd` does not unlock the LUKS2 root at early boot: it is an OS-level
authentication service that runs after the encrypted root becomes available.

## Default cold boot

```text
UEFI -> systemd-boot -> LUKS2 passphrase -> NixOS -> SDDM
```

This is deliberately the initial configuration.

## Hibernate

The 40 GiB swap LV is inside LUKS2, so the hibernation image is encrypted:

```text
LUKS2
└── LVM
    ├── 40 GiB swap
    └── Btrfs root
```

## Optional TPM2 auto-unlock

Do this only after confirming that passphrase boot, suspend, hibernate and
hibernate-resume all work, completing signed Secure Boot step 13 in
`docs/INSTALL.md`, and retaining a known-good recovery credential.

Verify that Secure Boot is actually enforced before enrolling a PCR-bound key:

```bash
bootctl status
sudo sbctl status
sudo sbctl verify
```

Stop unless Secure Boot reports enabled in user mode and the current NixOS EFI
generation is signed.

Identify the LUKS partition:

```bash
lsblk -o NAME,PATH,TYPE,FSTYPE,SIZE
ls -l /dev/disk/by-id/
LUKS_PARTITION="/dev/disk/by-id/REPLACE_WITH_THE_LUKS_PARTITION_ID"
test -b "$LUKS_PARTITION"
sudo cryptsetup luksDump "$LUKS_PARTITION"
```

Enroll TPM2 against PCR 7, which records the Secure Boot policy state, while
retaining your passphrase:

```bash
sudo systemd-cryptenroll --tpm2-device=auto \
  --tpm2-pcrs=7 \
  "$LUKS_PARTITION"
```

Then extend the existing LUKS `settings` block in
`hosts/framework-pro/disk.nix` and rebuild:

```nix
settings = {
  allowDiscards = true;
  crypttabExtraOpts = [ "tpm2-device=auto" ];
};
```

Do not run Disko again and do not remove the recovery/passphrase slot. Test a
cold boot and confirm that the passphrase still works as a fallback. A Secure
Boot key or firmware-policy change can invalidate the PCR value and should fall
back to that passphrase.

To remove only TPM2 enrollment after first verifying the passphrase, use:

```bash
sudo cryptsetup open --test-passphrase "$LUKS_PARTITION"
sudo systemd-cryptenroll --wipe-slot=tpm2 "$LUKS_PARTITION"
```

TPM2 auto-unlock and fingerprint authentication solve different problems:
TPM2 can release the disk key during boot; fingerprint authenticates the user
after Linux is running. PCR 7 binding detects a changed Secure Boot policy, but
does not bind the key to one exact kernel/initrd, and retaining Microsoft keys
widens the set of firmware-trusted binaries. The stronger Lanzaboote measured
boot/systemd-pcrlock path is not enabled by this repository because it needs a
separately verified and more brittle recovery design. Keep passphrase-only boot
if that boundary does not meet the threat model. TPM unlock does not replace
the recovery passphrase or protect data after login.

Primary references:

- [KDE KScreenLocker settings schema](https://github.com/KDE/kscreenlocker/blob/master/settings/kscreenlockersettings.kcfg)
- [systemd-cryptenroll](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html)
