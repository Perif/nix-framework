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
    plugins_order = [ ];
  };
}
