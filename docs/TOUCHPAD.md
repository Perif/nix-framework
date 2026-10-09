# Touchpad settings

This laptop uses Plasma Wayland. `settings.touchpad` selects user-session
defaults through Home Manager. Rebuild, then log out and back in to reload them.
These are a starting preference, not a hardware calibration or a measured fix.

| Setting | Default | Alternative |
| --- | --- | --- |
| `enable` | `true` | `false` stops managing these defaults; see removal below. |
| `disableWhileTyping` | `true` | `false` permits touchpad input while typing. |
| `tapToClick` | `true` | `false` requires physical clicks. |
| `tapAndDrag` | `false` | `true` enables double-tap-and-hold dragging. Physical press-and-drag still works when false. |
| `tapDragLock` | `false` | `true` keeps a tap-drag active briefly after lifting; only useful with tap-and-drag enabled. |
| `clickMethod` | `"clickfinger"` | `"button-areas"` uses the bottom-right area for right-click. |
| `naturalScrolling` | `false` | `true` makes content follow finger movement. |
| `pointerAcceleration` | `0.0` | Tune speed within `-1.0` to `1.0`; the driver acceleration profile stays unchanged. |
| `scrollFactor` | `1.0` | Try `0.75` for slower scrolling or `1.25` for faster scrolling. Must be positive. |

Two-finger scrolling is selected. One/two/three-finger taps map to
left/right/middle-click. With `clickfinger`, physical clicks also use finger
count; with `button-areas`, physical right-click uses the pad's lower-right area.
See libinput's [clickpad behavior](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html)
and [tapping behavior](https://wayland.freedesktop.org/libinput/doc/latest/tapping.html).

## Existing Plasma preferences and removal

The module writes only its keys under `[Libinput][Defaults][Touchpad]` in
`~/.config/kcminputrc`. It leaves mouse settings, other groups and the file's
writability intact. KWin's device-specific preferences override this group;
existing choices in System Settings can therefore take precedence. For an
existing installation, use **System Settings → Mouse & Touchpad → Touchpad** to
apply the same preferences to that device. A GUI change remains authoritative
for that device across rebuilds.

This behavior is verified against the pinned
[KWin 6.6.6 configuration loader](https://invent.kde.org/plasma/kwin/-/blob/v6.6.6/src/backends/libinput/connection.cpp)
and [device settings](https://invent.kde.org/plasma/kwin/-/blob/v6.6.6/src/backends/libinput/device.cpp).
Xorg `InputClass` snippets and NixOS `services.libinput` settings do not configure
this Wayland session. `libinput list-devices` reports driver defaults and
capabilities, not necessarily KWin's active preferences; see the
[libinput configuration documentation](https://wayland.freedesktop.org/libinput/doc/latest/configuration.html).

Disabling `touchpad.enable` leaves previously written values in place. To remove
only this module's defaults, set it to `false`, rebuild, and run as your login
user before logging out and back in:

```bash
for key in DisableWhileTyping TapToClick TapAndDrag TapDragLock LmrTapButtonMap \
           ClickMethod ScrollMethod NaturalScroll PointerAcceleration ScrollFactor; do
  kwriteconfig6 --file kcminputrc --group Libinput --group Defaults \
    --group Touchpad --key "$key" --delete
done
```

Per-device GUI preferences remain intact. Back up `kcminputrc` before manually
editing those overrides; deleting the entire file would also erase mouse and
other input-device preferences.

## Framework 13 Pro haptic click sensitivity

Haptic click sensitivity is separate from pointer speed, tap-to-click and palm
rejection. A [Framework Reddit discussion](https://www.reddit.com/r/framework/comments/1wcj90h/i_miss_the_mechanical_touchpad/)
reports that lowering sensitivity helped one user's sticky physical dragging;
it is an optional experiment, not a universal recommendation. Another
[right-click discussion](https://www.reddit.com/r/framework/comments/1vgac49/right_click_on_framework_13_pro/)
illustrates why clickfinger versus button areas is a preference.

For a **verified PIXA3854 haptic touchpad**, Framework's
[official Linux guide](https://knowledgebase.frame.work/how-to-adjust-haptic-touchpad-settings-BJjHJdU6bl)
documents sensitivity feature `80000` with levels 1/2/3 (low/medium/high), and
feedback intensity feature `90000` from 0 to 100. Do not apply these selectors to
another touchpad model. There is no boot-time HID write or automatic reapplication
in this configuration.

From this repository on the installed NixOS laptop, obtain the tool from the
locked Nixpkgs revision as your normal user, then discover the device:

```bash
hid_tools="$(nix build --inputs-from . nixpkgs#hid-tools --no-link --print-out-paths)"
sudo "$hid_tools/bin/hid-feature" list-devices
```

Select the node whose name starts with **PIXA3854**. The `/dev/hidrawN` number
can change across boots; do not copy a number from Reddit. Replace the placeholder
below with the discovered node, inspect the available fields, and record their
current values before changing anything:

```bash
touchpad_device=/dev/hidrawN
sudo "$hid_tools/bin/hid-feature" list "$touchpad_device" --fetch-values
# Only after verifying the device and feature IDs:
sudo "$hid_tools/bin/hid-feature" set "$touchpad_device" -f 80000 1
```

Test clicking and dragging before changing another value. To restore the old
sensitivity, use the same command with the value you recorded. If feedback
intensity also needs adjustment, use `-f 90000 VALUE`, replacing `VALUE` with
your chosen 0–100 value; restore its recorded value the same way. Recheck after
suspend/reboot rather than assuming persistence. The pinned `hid-tools` 0.7
provides this Python `hid-feature` CLI; unrelated programs with the same name
may use different flags.

If accidental palm input persists, first verify disable-while-typing in Plasma.
Test without keyboard remappers: a [NixOS keyd report](https://www.reddit.com/r/NixOS/comments/yprnch/)
describes a virtual keyboard interfering with that behavior. This repository
does not install keyd or add device quirks, pressure thresholds or palm dead zones.
Physical click pressure and palm rejection still need testing on your laptop.
