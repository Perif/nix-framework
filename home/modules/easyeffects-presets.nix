# Local variants are derived here so the downloaded originals stay unchanged.
let
  upstream = builtins.fromJSON (builtins.readFile ../../assets/audio/FW13SpeakersV2-Loudness.json);
  original = upstream.output;
in
{
  FW13SpeakersV2-Loudness = upstream;
  FW13Pro-bit0fun = builtins.fromJSON (builtins.readFile ../../assets/audio/FW13Pro-bit0fun.json);

  # Keep the original EQ curve and -19 dB input gain; remove its +11 dB
  # output gain, loudness stage and compressor. This is intentionally quieter,
  # not a new measured calibration or a hardware speaker-protection filter.
  FW13Pro-EQ-Limiter.output = {
    blocklist = [ ];
    plugins_order = [
      "equalizer#0"
      "limiter#0"
    ];
    "equalizer#0" = original."equalizer#0" // {
      "output-gain" = 0.0;
      balance = 0.0;
    };
    "limiter#0" = original."limiter#0" // {
      "gain-boost" = false;
      threshold = -1.0;
    };
  };

  Flat.output = {
    blocklist = [ ];
    # An empty output pipeline can leave a mono stream connected to only the
    # first channel of EasyEffects' virtual sink. Keep a neutral stereo stage
    # so both left and right channels are explicitly mapped through unchanged.
    plugins_order = [ "stereo_tools#0" ];
    "stereo_tools#0" = {
      bypass = false;
      "input-gain" = 0.0;
      "output-gain" = 0.0;
      "balance-in" = 0.0;
      "balance-out" = 0.0;
      softclip = false;
      mutel = false;
      muter = false;
      phasel = false;
      phaser = false;
      mode = "LR > LR (Stereo Default)";
      "side-level" = 0.0;
      "side-balance" = 0.0;
      "middle-level" = 0.0;
      "middle-panorama" = 0.0;
      "stereo-base" = 0.0;
      delay = 0.0;
      "sc-level" = 1.0;
      "stereo-phase" = 0.0;
      dry = -100.0;
      wet = 0.0;
    };
  };
}
