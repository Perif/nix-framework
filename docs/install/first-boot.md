# 5. Verify first boot

Run these checks in the installed Plasma session. Stop and investigate any
unexpected result before enabling Secure Boot or TPM unlock.

## 1. Check services, storage and time

```bash
systemctl --failed
for mountpoint in / /home /nix /var/log /.snapshots /boot /var/lib/private/ollama; do
  findmnt --mountpoint "$mountpoint"
done
swapon --show
timedatectl status
```

**Expected:** no unexpected failed units; each mount exists; encrypted physical
swap and zram are present; timezone matches your choice and the clock becomes
synchronized after networking connects. `systemctl --failed` exits successfully
even when it lists failures: read its output. In Plasma, set the clock to **Local**.

## 2. Check networking and graphics

```bash
resolvectl query example.com
resolvectl status
vulkaninfo --summary
vainfo
systemctl is-active thermald.service
```

**Expected:** DNS resolves; default DNS points to loopback Blocky; Vulkan shows
the Intel GPU; VA-API lists supported codecs; thermald is active. Installed
drivers alone do not prove that an application uses GPU acceleration.

## 3. Check login, display, audio and sleep

1. Open a new terminal. Confirm your username and that `sudo -v` accepts your
   account password.
2. Verify brightness, touchpad and speakers. Confirm the built-in display has
   HDR disabled. Select an ICC profile only after [matching the panel](../DISPLAY.md).
3. Save your work. Run `loginctl lock-session` and unlock with your password.
4. Run `systemctl suspend`; resume and verify the lock screen, Wi-Fi and audio.
5. After suspend works, run `systemctl hibernate`; resume and repeat the checks.
6. Test `systemctl suspend-then-hibernate` separately before relying on the
   default combined sleep policy.

## 4. Set up only the features you use

| Feature | Next step |
| --- | --- |
| Speaker EQ and DC-Elite | [Audio setup](../AUDIO.md) |
| Local models and Continue | [Local AI setup](../LOCAL-AI-DEVELOPMENT.md) |
| REA/Ghidra | [REA setup](../REA.md) |
| Open WebUI, KeePassXC, Wine and developer tools | [Applications](../WORKSTATION-APPS.md) |
| AC/battery refresh rates | [Display policy](../DISPLAY.md) |
| Battery and acceleration baseline | [Measurements](../POWER-MEASUREMENTS.md) |
| Fingerprint reader and later TPM unlock | [Fingerprint/TPM](../FINGERPRINT-TPM.md) |
| Signed boot, after normal boot and recovery work | [Secure Boot](secure-boot.md) |

For deeper checks of disk health, maintenance, browser policy and hardware,
use [extended verification](../reference/first-boot-checks.md).
For subsequent changes, use [edit → test → verify → apply](customization.md).
