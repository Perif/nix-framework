# Display color

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
