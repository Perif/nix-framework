# Display color and SDR

## HDR disabled on the built-in panel

`display.disableHdr = true` is the default. At Plasma Wayland login and after
saved display changes, the configuration turns off HDR, wide-color-gamut output
mode and extended dynamic range (EDR) on enabled built-in `eDP-*` panels. EDR is
Plasma's additional dynamic-range mode for laptop backlights; it is disabled
even when the panel does not advertise conventional HDR support. Unsupported
controls are skipped. This is an explicit SDR preference, not a claim about
your particular panel's HDR certification.

The policy uses `kscreen-doctor` from the pinned KDE 6.6.6 release. See KDE's
[HDR/EDR controls](https://invent.kde.org/plasma/libkscreen/-/blob/v6.6.6/src/doctor/doctor.cpp)
and [ICC handling](https://invent.kde.org/plasma/kwin/-/blob/v6.6.6/src/backends/drm/drm_output.cpp).
It preserves resolution, scaling, brightness settings and the selected ICC
profile. Refresh rate is unchanged unless the optional policy below is enabled. External monitors keep their own HDR/color settings.
There is no periodic polling or replacement of KWin's monitor-layout file.

After rebuilding, log out and back in. In a Plasma terminal, run:

```bash
kscreen-doctor -o
```

For the built-in output, expect **HDR: disabled** (or **incapable**), **Wide
Color Gamut: disabled** (or **incapable**) and **Allow EDR: never** (or
**unsupported**). To apply immediately in an existing session:

```bash
systemctl --user daemon-reload
systemctl --user start framework-display-sdr.path framework-display-sdr.service
```

Check failures with `journalctl --user -u framework-display-sdr.service`.
Set `display.disableHdr = false`, rebuild, then log out/in to manage these
controls manually again. This stops enforcement; it does not turn HDR back on.
The policy does not manage the SDDM login screen. Display behavior after login,
docking and suspend still needs verification on the actual laptop.

## Optional battery refresh preset

The default `display.refreshRate.enable = false` leaves refresh selection in
Plasma. To opt in, edit the existing `display.refreshRate` block:

```nix
refreshRate = {
  enable = true;
  batteryHz = 60;
  acHz = null; # Highest advertised rate at the current resolution, or e.g. 120.
};
```

After rebuilding, log out/in. The same display helper reads UPower's current
power source at login, after saved display changes, and when Plasma enters its
AC, Battery or LowBattery profile. It selects only an advertised mode at the
**current resolution of an enabled internal eDP panel**. A 59.94 Hz mode counts
as 60 Hz (0.5 Hz tolerance). If the requested rate is unavailable, it logs that
fact and keeps the current mode; it never creates modes or changes resolution.
External monitors, ICC selection, brightness and scaling remain as configured.
HDR enforcement remains independently controlled by `display.disableHdr`.

This uses Plasma's `RunScript/ProfileLoadCommand` hook, with no polling daemon.
While enabled, the hook is managed by this configuration; any previous profile
load command is saved under `FrameworkRefreshPolicy` in `powerdevilrc` and
restored when you disable the option. It does not run the previous command
alongside the policy. Unload/idle commands are preserved. Repeated activation
keeps the saved command, and opting out preserves a replacement command you
subsequently entered in the GUI. Rapid power transitions restart the oneshot
so that the last transition gets a fresh UPower read.

Test unplugging/reconnecting power, closing/reopening the lid, and docking with
`kscreen-doctor -o`. Inspect failures with
`journalctl --user -u framework-display-sdr.service`. If UPower or mode parsing
fails, the helper still attempts the independent SDR policy and reports failure.

To opt out, set `enable = false`, rebuild and log out/in, then select your
preferred refresh rate in **Display Configuration**. Disabling management does
not undo the last mode KWin saved. If only HDR enforcement is still enabled,
the existing service continues to enforce SDR without changing refresh rates.

The [Framework battery discussion](https://community.frame.work/t/can-i-improve-upon-10-hours-of-battery-on-13-pro-limited-batch/84519)
motivates this selectable tradeoff; its combined-setting reports do not establish
a universal saving. Compare comfort and whole-system power using the
[measurement guide](POWER-MEASUREMENTS.md).

## ICC calibration

By default, Home Manager installs the Notebookcheck **Framework Laptop 13 Pro /
MND508ZB1-1** ICC profile at `~/.local/share/color/icc/framework-13-pro.icm`. See
[source and checksum](../assets/README.md). “ICC” is the display-profile format;
IPP is the printing protocol.

This is a useful borrowed calibration for the matching panel. A calibration
measured on your own display at your working brightness is preferable. Do not
substitute profiles for the older BOE 2.8K panel or the original 2256 × 1504
Framework display. Notebookcheck's improved measurements describe its sample,
not a guaranteed result for every unit.

## Select once in Plasma

1. After rebuilding, inspect the internal display's EDID:

   ```bash
   for panel in /sys/class/drm/card*-eDP-*/edid; do
     [ -s "$panel" ] && edid-decode "$panel"
   done
   ```

   Check the panel identity against MND508ZB1-1. If EDID reports only a vendor
   code, confirm the panel through its hardware details before selecting it.
2. Open **System Settings → Display & Monitor → Display Configuration**.
   Select the built-in display and choose **ICC profile** as its color profile.
   Browse to `~/.local/share/color/icc/framework-13-pro.icm` and Apply.
3. Compare neutral greys, skin tones and shadow detail, with Night Color off
   for the comparison. Revert to the built-in/default profile if it looks worse.
4. Reboot and check that the profile is still selected. Do not assign it to
   external displays.

KWin owns display color management on this Wayland session. Installing a
profile in colord alone does not apply it to the screen. The
[KDE display tool](https://invent.kde.org/plasma/libkscreen/-/blob/Plasma/6.4/src/doctor/doctor.cpp)
also supports `kscreen-doctor "output.eDP-1.iccprofile.<absolute-path>"`;
first use `kscreen-doctor -o` to obtain the actual connector name.

## Profile options

| `display.profile` | Behavior and use |
| --- | --- |
| `"notebookcheck"` | Default: the borrowed MND508ZB1-1 calibration is installed at the stable filename above. Use only with the matching panel. |
| `"native"` | No selected-profile alias is installed. Choose Plasma's default/no-ICC mode manually for an uncorrected comparison or if the borrowed calibration looks worse. This is a mode, not another ICC file or a claim of factory calibration. |
| `"custom"` | Your own ICC is installed at the stable filename. Requires `display.iccProfile`; prefer a measurement of your actual panel at your working brightness. |

Change the existing `display` block in `settings.nix`, for example:

```nix
display = {
  disableHdr = true;
  refreshRate = { enable = false; batteryHz = 60; acHz = null; };
  profile = "custom";
  iccProfile = ./assets/color/my-panel.icc;
  extraIccProfiles = {
    studio120 = ./assets/color/my-panel-120nits.icc;
    office200 = ./assets/color/my-panel-200nits.icc;
  };
};
```

These paths are examples: supply actual ICC files or leave `extraIccProfiles`
empty. Extra names accept letters, digits, underscores and hyphens. Profiles
are installed as `~/.local/share/color/icc/framework/custom-<name>.icc` and
can be chosen directly in Plasma without another rebuild. The original
Notebookcheck file always remains available as
`~/.local/share/color/icc/framework/notebookcheck-MND508ZB1-1.icm`.

**A configuration switch changes installed files, not KWin's current profile.**
After rebuilding, reselect the desired ICC in Display Configuration and Apply,
even if the stable filename is unchanged. Before switching to `native`, select
the default/no-ICC mode in Plasma so KWin does not retain a path to the alias
that the rebuild removes. For a temporary comparison, switching modes in
Plasma alone is sufficient.

No second independently verified calibration for this exact panel is bundled.
An sRGB working-space profile is not a substitute for measuring the display,
and older Framework-panel ICCs are not alternatives for this panel. Keep each
custom calibration labeled with its panel and measurement brightness; select
the matching brightness when comparing. The configuration does not guess the
panel or overwrite KWin's monitor layout. Actual color accuracy requires
measurement on the laptop.
