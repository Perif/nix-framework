# Laptop speakers and iBasso DC-Elite audio

## EasyEffects speaker preset

EasyEffects starts with the graphical session through Home Manager. The
installed **FW13SpeakersV2-Loudness** preset targets the Framework **13 Pro**
chassis. It is the recommended starting point here based on the author's
Pro-specific work and current owner feedback, not a measured consensus winner.
See [the pinned source](../assets/README.md) and
[the author's description](https://www.reddit.com/r/framework/comments/1wc4alx/v2_of_framework_13_pro_easyeffects_profile/).
Older Framework 13 presets, including Gracefu/cab404 variants, were tuned on
different hardware. The [Pro-specific alternative by bit0fun](https://www.reddit.com/r/framework/comments/1w1phiy/improved_easyeffects_eq_for_fw13pro/)
has useful measurement work, but its author and users report compressor/maximizer pumping;
it is not the default here.

After rebuilding, log out and back in, or close EasyEffects and run:

```bash
systemctl --user restart easyeffects
```

1. Select the **built-in speakers** as the system output; unplug headphones.
2. Open EasyEffects, select Output, and load `FW13SpeakersV2-Loudness`.
3. In Presets → Autoload, associate it with the built-in speaker device **and
   speaker route**. Do not associate it with the whole sound card regardless of
   route: the same card can also drive the headphone jack.
4. The service sets the output fallback to **Flat**, an empty effects chain,
   and leaves microphone stream processing disabled. Confirm the fallback in
   the GUI. Unmatched outputs/routes should load Flat.
5. Test speaker → wired headphones → speakers, then Bluetooth/HDMI if used.
   Confirm Flat loads on other outputs and the speaker preset returns on the
   speaker route. Start at modest volume and listen for rattling or distortion;
   the preset includes substantial gain and its limiter is not physical speaker
   protection. Keep the system volume at or below 100%.

The [EasyEffects manual](https://wwmm.github.io/easyeffects/user_interface/userpresets.html)
explains preset associations. Until the association is made, the preset is
installed but not automatically applied. Hardware names cannot be determined
from this macOS workspace.

For a declarative association, read the JSON created by EasyEffects under
`~/.local/share/easyeffects/autoload/output/`. Copy its `device` and
`device-profile` values into `audio.speakerDevice` and `audio.speakerRoute` in
`settings.nix`, respectively, then rebuild. Both fields must be set together.
Home Manager will own that rule; modify these settings rather than editing the
managed JSON. Remove any other manually created rules for headphones/external
outputs if you want them to use the Flat fallback.

The managed presets are under `~/.local/share/easyeffects/output/`.
Duplicate a preset under a new name before experimenting in the GUI; managed
files are read-only. `Flat` removes DSP effects but still uses PipeWire; it is
not the exclusive direct-ALSA path described below.

## Choosing another preset

All four bundled presets appear in EasyEffects' Output preset list. Load one
to compare, then update the speaker association in Autoload if you want it to
persist. Compare at similar perceived loudness; a louder preset can sound
better simply because it is louder.

| Preset name | Use and tradeoff |
| --- | --- |
| `FW13SpeakersV2-Loudness` | Current default. Original Pro-specific EQ, loudness, compressor and limiter; useful starting point for everyday playback. |
| `FW13Pro-EQ-Limiter` | Local variant using the same EQ curve, without loudness or compressor. Keeps -19 dB EQ input gain, removes +11 dB output gain, centers balance, and uses a -1 dB limiter threshold with gain boost off. Intentionally quieter; try if you dislike dynamic processing. Not independently measured. |
| `FW13Pro-bit0fun` | Alternative Pro EQ based on the author's Zoom H4n recordings. Original maximizer, EQ, compressor and limiter retained. Experimental comparison: pumping has been reported. |
| `Flat` | Empty effects chain for comparison or no speaker EQ. Also the fallback for unmatched devices/routes. |
| `Custom` | Your own exported EasyEffects output preset, installed only when `audio.customPreset` is set. |

For a declarative speaker association, change **one value** in `settings.nix`:

```nix
audio = {
  speakerPreset = "FW13Pro-EQ-Limiter";
  customPreset = null;
  speakerDevice = "YOUR-EXACT-DEVICE";
  speakerRoute = "YOUR-EXACT-SPEAKER-ROUTE";
};
```

Keep the real device/route values obtained above; do not copy these placeholders.
With both fields null, `speakerPreset` does not load anything globally or
change GUI-created rules. Use the GUI association instead. When Nix owns the
rule, rebuild and restart EasyEffects after changing `speakerPreset`; changing
only the currently loaded GUI preset does not update that declarative rule.

For your own preset, export an **Output** preset as JSON and use:

```nix
audio.speakerPreset = "Custom";
audio.customPreset = ./assets/audio/my-speakers.json;
```

These lines replace the corresponding fields in the existing `audio` block;
do not declare a field twice. The file must have only an `output` top-level
object and a `plugins_order` array. External impulse responses/models are not
bundled by this option; provide those separately if your custom preset uses
them. The bundled presets need no such files. See
[sources and local modifications](../assets/README.md).

## Design

There are two separate paths:

### Desktop

```text
KDE / browsers / normal apps -> PipeWire
```

With the speaker association configured, EasyEffects processes desktop output
before the internal speakers. The DC-Elite remains excluded from WirePlumber,
so Strawberry/QBZ direct ALSA never enters the EasyEffects pipeline.

Strawberry, qobuz-player and MusicBrainz Picard are installed by default.
Strawberry handles local playback, qobuz-player provides Qobuz streaming, and
Picard edits local music tags and cover art. Picard is not the direct-DAC player.

PipeWire is allowed to switch among:

- 44.1 / 48 kHz
- 88.2 / 96 kHz
- 176.4 / 192 kHz
- 352.8 / 384 kHz
- 705.6 / 768 kHz

### Strict Strawberry path

```text
Strawberry -> ALSA hw: -> iBasso DC-Elite
```

The NixOS WirePlumber module uses `device.disabled = true` for the DC-Elite.
This prevents PipeWire/WirePlumber from owning the DAC and leaves direct ALSA
hardware access available.

The direct `hw` ALSA path is the important part for avoiding a software
resampler/mixer. Do not use ALSA `plug` for this strict path.

## First boot

Connect the DC-Elite:

```bash
aplay -l
```

Generate a card-specific stanza:

```bash
dc-elite-alsa-config
```

Place the output in:

```text
~/.asoundrc
```

Then configure Strawberry to use ALSA and the `dc_elite` device.

Disable:

- EQ
- ReplayGain / normalization
- crossfade
- BS2B
- other DSP
- software volume processing

Keep digital playback at unity and use the DC-Elite's hardware volume.

## Verify actual hardware rate

While playing:

```bash
grep -R . /proc/asound/card*/pcm*p/sub*/hw_params 2>/dev/null
```

A 44.1 kHz track should show `rate: 44100`; a 96 kHz track should show
`rate: 96000`; etc.

## DSD

The configuration makes a strict claim only for PCM. Native DSD vs DoP depends
on Strawberry/GStreamer and the formats exposed by ALSA USB Audio. Verify DSD
separately instead of assuming native DSD512.


## qobuz-player / Qobine

The installed command is `qobuz-player` (0.9.0 in the current lock).
[Upstream moved to Qobine](https://github.com/SofusA/qobuz-player); its lineage
started with [hifi.rs](https://github.com/iamdb/hifi.rs). The local package
override changes the download location to `SofusA/qobine` while preserving
Nixpkgs' release, source hash and Cargo dependency hash. It does not install
Qobine's latest development version or its newer split application commands.

Start with browser login and inspect the available output descriptions:

```bash
qobuz-player login
qobuz-player list-devices
```

A paid Qobuz subscription is required. Keep account credentials out of Nix
configuration. Then copy the exact DC-Elite hardware device description from
the list into this command (replace the placeholder):

```bash
qobuz-player open --output-device-id 'EXACT DC-ELITE HARDWARE DEVICE DESCRIPTION'
```

Despite the flag's name, version 0.9.0 compares the full device description
printed by `list-devices`; do not assume it accepts a bare ALSA card number or
the `dc_elite` alias. Select the hardware endpoint, not `default`, PipeWire,
PulseAudio or a `plughw` conversion endpoint. Stop Strawberry or any other
direct player before opening the DAC. No player service, web interface or
Qobuz Connect listener is enabled automatically.

Keep the player's volume at 100% and adjust listening level on the DC-Elite.
The existing WirePlumber exclusion leaves the DAC available to ALSA. However,
this release uses Rodio/CPAL, requests the source sample rate and calls
`open_sink_or_fallback()`: device selection alone is **not a guarantee of
bit-perfect output**. Check the active hardware rate using the command above
with 44.1, 48 and 96 kHz tracks. Matching rates are necessary but do not prove
that sample format conversion or digital processing is absent. Login,
playback and DAC behavior still require testing on the laptop.

For strict local PCM playback, use the Strawberry setup above. For another
Qobuz candidate, [Ricercar](https://github.com/ricercar-player/ricercar) documents
raw `hw:` ALSA output and refusal of unsupported formats; its separate
[community Qobuz plugin](https://github.com/ricercar-player/ricercar-plugins)
is unofficial. Neither is installed or hardware-tested by this configuration.

## MusicBrainz Picard

Launch **MusicBrainz Picard** from Plasma or run `picard`. Review album matches,
metadata and destination filenames before saving changes to your music files,
then rescan the affected library in Strawberry. No automatic tagging, renaming
or library changes are configured.

## QBZ / Qobuz

QBZ is disabled by default: [upstream distribution has closed](https://github.com/vicrodh/qbz)
and the former pinned download returns 404. The README describes the optional
`qbz.packageFile` hook for an independently maintained package. The following
notes apply only if such a package is installed; they are not a guarantee of
continued Qobuz service compatibility.

For the iBasso DC-Elite, configure QBZ to use:

```text
Audio backend: ALSA Direct
Device:        iBasso DC-Elite / corresponding hw: device
Exclusive:     enabled
```

QBZ supports direct ALSA hardware access and per-track sample-rate switching.
Qobuz streaming itself tops out at 24-bit / 192 kHz, so QBZ should switch the
DAC among the source rates delivered by Qobuz without resampling.

The WirePlumber rule in `modules/nixos/audio.nix` keeps the DC-Elite out of
PipeWire ownership. That allows either Strawberry or QBZ to acquire the DAC
directly, but only one direct-ALSA player can own the hardware device at a time.

Direct-ALSA paths (QBZ only when separately supplied):

```text
Qobuz        -> QBZ        -> ALSA Direct -> DC-Elite
Local music  -> Strawberry -> ALSA hw:     -> DC-Elite
```

To verify the actual active ALSA hardware rate while QBZ is playing:

```bash
grep -R . /proc/asound/card*/pcm*p/sub*/hw_params 2>/dev/null
```
