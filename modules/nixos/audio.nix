{ ... }:

{
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    alsa = {
      enable = true;
      support32Bit = true;
    };

    pulse.enable = true;
    wireplumber.enable = true;

    # Normal desktop audio: allow the PipeWire graph to follow common
    # native PCM rates through the DC-Elite's 768 kHz ceiling.
    #
    # The strict Strawberry -> DC-Elite path bypasses PipeWire entirely.
    extraConfig.pipewire."10-audiophile"."context.properties" = {
      "default.clock.rate" = 44100;

      "default.clock.allowed-rates" = [
        44100
        48000
        88200
        96000
        176400
        192000
        352800
        384000
        705600
        768000
      ];
    };

    # resample.quality is a stream property. It belongs in the client
    # configurations (native clients and the PulseAudio shim), not in
    # pipewire.conf's context.properties, where it is silently ignored.
    # Used only when resampling cannot be avoided.
    extraConfig.client."10-audiophile"."stream.properties" = {
      "resample.quality" = 10;
    };

    extraConfig.pipewire-pulse."10-audiophile"."stream.properties" = {
      "resample.quality" = 10;
    };

    # Exclude the DC-Elite from WirePlumber/PipeWire ownership so that
    # Strawberry can open the ALSA hardware endpoint directly.
    #
    # WirePlumber documents device.disabled as preventing creation of
    # that ALSA device in WirePlumber.
    wireplumber.extraConfig."51-dc-elite-exclusive" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            {
              "device.product.name" = "~.*DC[- ]?Elite.*";
            }
          ];

          actions = {
            update-props = {
              "device.disabled" = true;
            };
          };
        }
      ];
    };
  };
}
