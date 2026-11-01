# Profile sources

The ICC and JSON files are unmodified upstream downloads, retrieved 2026-09-28. They are
data, not executable installers. Upstream authors retain their rights.

## Display

- File: `color/framework-13-pro-MND508ZB1-1.icm`
- Source: [Notebookcheck Framework Laptop 13 Pro review](https://www.notebookcheck.net/Framework-Laptop-13-Pro-review-The-king-of-repairability-is-back.1351246.0.html), published 2026-07-28.
- [Original download](https://www.notebookcheck.net/uploads/tx_nbc2/CSW1322.icm)
- Tested panel: MND508ZB1-1, 2880 × 1920, 120 Hz; X-Rite i1Pro 3.
- SHA-256: `fbf94d5908514e8d9aacc6f95e1b6998a9a69a8f6c833ac3d1a77f78c19c06e3`

## Speakers

- File: `audio/FW13SpeakersV2-Loudness.json`
- Author: stirlingsilver / lifeislikeavco.
- [Immutable source](https://github.com/stirlingsilver/fw13pro-customizations/blob/9c6aa1210630d608063dbcfb268f615bed1d3a34/FW13SpeakersV2-Loudness.json)
- [Author's explanation and feedback](https://www.reddit.com/r/framework/comments/1wc4alx/v2_of_framework_13_pro_easyeffects_profile/)
- SHA-256: `428d323fa377b303093dd848227f9b3399b5669017f559c43764a92e920e5807`

The preset targets the Pro chassis. Its four effects are EQ, loudness,
compressor, and limiter, in that order. It needs no external impulse response.
It is a subjective community tuning, not a certified flat response or a
proven consensus winner. Keep upstream updates deliberate and compare by ear.

### Alternative: bit0fun

- File: `audio/FW13Pro-bit0fun.json` (original name: `FW13Pro_EQ.json`).
- Author: bit0fun.
- [Pinned Gist revision](https://gist.github.com/bit0fun/7567063dc867b12a1e7ed420da44693d/99900b2eb694e2b722a724b8ce7f65d90f3fa7d5)
- [Raw file](https://gist.githubusercontent.com/bit0fun/7567063dc867b12a1e7ed420da44693d/raw/dc0039fed68326047cc2355e92c7a63b7d1ebc89/FW13Pro_EQ.json)
- SHA-256: `2173a74ea1c4adc8b9807ce4acab9d0a5855eb09aabc4efa5950686c8797472a`
- The author used Zoom H4n recordings of the Pro. This is an optional
  comparison, not an accuracy guarantee; the original dynamics stages are
  retained. [Reports and author responses](https://www.reddit.com/r/framework/comments/1w1phiy/improved_easyeffects_eq_for_fw13pro/).

### Local variants

`home/modules/easyeffects-presets.nix` generates `FW13Pro-EQ-Limiter` from the
first source's EQ and limiter, and generates the neutral stereo `Flat` preset. The local
variant removes loudness/compression, sets EQ output gain and balance to zero,
and sets the limiter threshold to -1 dB with gain boost disabled. It retains
the original -19 dB EQ input gain. These changes are not upstream recommendations
or newly measured speaker corrections. The source JSON stays unchanged.
