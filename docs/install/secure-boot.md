# Enable signed Secure Boot

Do this only after the normal unsigned installation, recovery-passphrase boot, hibernation, firmware updates, and first-boot checks work. Keep the NixOS installer USB available. If signed boot fails, disable Secure Boot enforcement in firmware and boot the previous working configuration.

Complete this only after normal boot, hibernation, recovery-passphrase boot,
firmware updates, and the previous verification steps all work. Keep the NixOS
installer USB available. If signed boot fails, disable Secure Boot enforcement
in firmware and boot the previous working configuration.

Confirm firmware state and create machine-local keys:

```bash
sudo sbctl status
sudo sbctl create-keys
sudo ls -la /var/lib/sbctl
```

The private keys under `/var/lib/sbctl` must never be copied into this
repository or the Nix store. Back them up only to encrypted offline storage.

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
sudo nixos-rebuild dry-build --flake ".#${INSTALL_HOST}"
sudo nixos-rebuild switch --flake ".#${INSTALL_HOST}"
sudo sbctl verify
```

The Lanzaboote verification output may list old raw `kernel-*` files as
unsigned; the EFI boot entries and unified NixOS generation images must be
signed.

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

Reboot into firmware again, enable **Enforce Secure Boot**, boot NixOS, and
verify the final state:

```bash
bootctl status
sudo sbctl status
sudo sbctl verify
```

`bootctl status` must report Secure Boot enabled in user mode. Keep
`features.secureBoot = true` for future rebuilds. Only after this is stable
should TPM2 auto-unlock be considered; see `docs/FINGERPRINT-TPM.md`. Confirm
that the firmware forbidden-signature database (`dbx`) is present and current,
then set a strong firmware administrator password so an unattended person
cannot simply change the Secure Boot policy. Store that password with the LUKS
recovery credential; losing it can make firmware recovery difficult.

Reboot into firmware one final time and verify that changing Secure Boot state
or key-management settings requires the new administrator password. Boot NixOS
again and repeat the three status checks above. Do not consider the Secure Boot
procedure complete until both the password gate and signed-boot verification
have passed.
