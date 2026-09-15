# iBasso DC-Elite audio

## Design

There are two separate paths:

### Desktop

```text
KDE / browsers / normal apps -> PipeWire
```

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


## QBZ / Qobuz

QBZ is installed from its upstream Nix flake.

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

Recommended use:

```text
Qobuz        -> QBZ        -> ALSA Direct -> DC-Elite
Local music  -> Strawberry -> ALSA hw:     -> DC-Elite
```

To verify the actual active ALSA hardware rate while QBZ is playing:

```bash
grep -R . /proc/asound/card*/pcm*p/sub*/hw_params 2>/dev/null
```
