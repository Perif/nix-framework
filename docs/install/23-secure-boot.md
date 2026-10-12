# Enable signed Secure Boot

Guide 23 · [All guides](../README.md).

Do this only after the normal unsigned installation, recovery-passphrase boot, hibernation, firmware updates, and first-boot checks work. Keep the NixOS installer USB available. If signed boot fails, disable Secure Boot enforcement in firmware and boot the previous working configuration.

## 1. Create and back up signing keys

Confirm firmware state and create machine-local keys:

```bash
sudo sbctl status
sudo sbctl create-keys
sudo ls -la /var/lib/sbctl
```

The private keys under `/var/lib/sbctl` must never be copied into this
repository or the Nix store. Back them up only to encrypted offline storage.

## 2. Build the signed generation

In `/etc/nixos/settings.nix`, change only `secureBoot` inside the existing
`features` block; preserve the QBZ and Thunderbolt choices:

```nix
secureBoot = true;
```

Evaluate, install the signed Lanzaboote generation, and verify the EFI images
before changing firmware key state:

```bash
cd /etc/nixos
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild build --flake ".#${INSTALL_HOST}"
```

Stop if the build fails. After it succeeds, install the signed generation:

```bash
sudo nixos-rebuild switch --flake ".#${INSTALL_HOST}"
sudo sbctl verify
```

The Lanzaboote verification output may list old raw `kernel-*` files as
unsigned; the EFI boot entries and unified NixOS generation images must be
signed.

## 3. Enroll keys in firmware Setup Mode

Reboot into the Framework firmware and enter Secure Boot Setup Mode. Under
**Administer Secure Boot**, delete the individual entries under PK, KEK, and DB
as described by Lanzaboote. Do **not** select **Erase all Secure Boot Settings**;
Lanzaboote documents that option as unsafe on affected Framework firmware.
Boot back into NixOS, then retain both Microsoft and firmware-provisioned keys
when enrolling:

```bash
sudo sbctl enroll-keys --microsoft --firmware-builtin
sudo sbctl status
sudo sbctl verify
```

## 4. Enable and verify enforcement

Reboot into firmware again, enable **Enforce Secure Boot**, boot NixOS, and
verify the final state:

```bash
bootctl status
sudo sbctl status
sudo sbctl verify
```

`bootctl status` must report Secure Boot enabled in user mode. Keep
`features.secureBoot = true` for future rebuilds. Only after this is stable
should TPM2 auto-unlock be considered; see [Fingerprint/TPM](../24-fingerprint-tpm.md).

## 5. Protect firmware settings

Confirm
that the firmware forbidden-signature database (`dbx`) is present and current,
then set a strong firmware administrator password so an unattended person
cannot simply change the Secure Boot policy. Store that password with the LUKS
recovery credential; losing it can make firmware recovery difficult.

Reboot into firmware one final time and verify that changing Secure Boot state
or key-management settings requires the new administrator password. Boot NixOS
again and repeat the three status checks above. Do not consider the Secure Boot
procedure complete until both the password gate and signed-boot verification
have passed.
