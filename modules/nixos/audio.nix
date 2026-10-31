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

    # Prefer the DC-Elite whenever it is connected. Its node must remain in
    # PipeWire for Plasma to see it and route desktop streams to it; hiding it
    # entirely made desktop playback fall back to the internal speakers.
    #
    # Strawberry keeps its separate `hw:DCElite,0` ALSA path. Suspending this
    # PipeWire node promptly while idle releases the hardware for Strawberry's
    # direct stream. A direct ALSA stream and a desktop PipeWire stream cannot
    # use the physical DAC concurrently.
    wireplumber.extraConfig."51-dc-elite-routing" = {
      "wireplumber.settings" = {
        # Do not let a previously clicked Plasma default override the priority
        # policy when the DC-Elite is connected or removed.
        "node.restore-default-targets" = false;
      };

      "monitor.alsa.rules" = [
        {
          matches = [
            {
              "node.name" = "~alsa_output.usb-iBasso.*";
            }
          ];

          actions = {
            update-props = {
              # Higher than the internal analog sink (1009) and common USB
              # defaults, so WirePlumber selects it on hot-plug.
              "priority.session" = 2000;
              "session.suspend-timeout-seconds" = 1;
            };
          };
        }
      ];
    };
  };
}
