# Xbox Elite Series 2

The build enables xpadneo for Bluetooth and the kernel xpad driver for a USB-C
data cable. It also loads `uhid` for BlueZ/Bluetooth LE firmware and includes
`evtest` for local input diagnostics. No Steam account or background gaming
service is required. Microsoft's proprietary Xbox Wireless USB adapter is a
different transport: its xone driver is **not enabled** by this configuration.

## Apply the configuration

On a fresh installation the drivers are included automatically. On an existing
installation, complete any outstanding storage migration described in
[INSTALL.md](INSTALL.md) before rebuilding. From `/etc/nixos`:

```bash
INSTALL_HOST="$(nix eval --raw --impure --expr '(import ./settings.nix).hostname')"
sudo nixos-rebuild boot --flake ".#${INSTALL_HOST}"
sudo reboot
```

Rebooting ensures the running kernel and installed controller module match.
Do not run upstream DKMS installers or disable Secure Boot to install a driver.
This adds an out-of-tree kernel module, so a successful build against the pinned
kernel is required; evaluation alone does not prove kernel compatibility.

## USB-C

Connect the controller with a data-capable USB-C cable. No Bluetooth pairing is
needed. Verify buttons and sticks in the game's controller settings. Bluetooth
can remain powered off. Controller audio and advanced features should not be
assumed to work identically across USB and Bluetooth.

## Bluetooth pairing in Plasma

1. Enable Bluetooth in Plasma's system tray. It intentionally starts powered
   off after boot, preserving this build's existing privacy policy.
2. Turn on the controller and hold its pairing button until the Xbox light
   flashes rapidly.
3. Open Plasma's Bluetooth device settings, add the Xbox controller, and pair.
4. Connect it and test the buttons/sticks in your application. Enable Bluetooth
   again after each reboot when you want wireless use; the pairing is retained.

Alternatively, run `bluetoothctl` in a terminal and enter:

```text
power on
agent on
default-agent
scan on
```

Put the controller into pairing mode and identify its address. Replace
`CONTROLLER_ADDRESS` below with that address, not the laptop adapter address:

```text
scan off
pair CONTROLLER_ADDRESS
trust CONTROLLER_ADDRESS
connect CONTROLLER_ADDRESS
info CONTROLLER_ADDRESS
quit
```

Trust only your own controller. Do not publish its Bluetooth address in Git.
To switch off wireless use later, use Plasma or `bluetoothctl power off`.
No global discoverable mode, permissive Bluetooth security overrides, firewall
ports, or broad input-device permissions are added.

## Features and limitations

xpadneo supports Elite Series 2 input, rumble, paddles, battery reporting and
native profile switching. Application mapping and controller firmware affect
what a game exposes. The default profile (no profile LED) exposes paddles as
extra buttons; stored mappings in the other profiles may duplicate buttons.
Use Xbox Accessories on Windows or Xbox for supported firmware updates and
profile/sensitivity editing: xpadneo does not upload those profiles. Bluetooth
headset audio through the controller is unsupported.

See the [upstream Elite Series 2 notes](https://github.com/atar-axis/xpadneo#xbox-elite-series-2-wireless-controller)
and [profile behavior](https://github.com/atar-axis/xpadneo#native-profile-switching-support).

## Verify and troubleshoot

```bash
lsmod | grep -E 'hid_xpadneo|xpad|uhid'
bluetoothctl show
sudo journalctl -b -u bluetooth.service
sudo journalctl -b -k | grep -Ei 'xpad|xbox|uhid|bluetooth'
sudo evtest
```

In `evtest`, select only the Xbox controller's event device, then exercise its
buttons, sticks and triggers. Exit with Ctrl+C. Do not select a keyboard or
capture unrelated input. Rumble must also be tested in a supporting game.
If raw events work but a game does not, inspect that game's input mapping or
Steam Input settings if you already use Steam; do not install competing kernel
drivers as a first fix. If pairing breaks after a firmware update, remove only
the controller's saved pairing in Plasma and pair it again.

Pairing, rumble, reconnect after suspend, and the selected firmware require a
physical-controller test; they cannot be verified by Nix evaluation on macOS.
