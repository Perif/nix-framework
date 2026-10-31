{ ... }:

{
  # The DC-Elite's stable ALSA card identifier avoids a boot-dependent card
  # index while retaining direct, unconverted hardware access.
  home.file.".asoundrc".text = ''
    pcm.dc_elite {
        type hw
        card "[iBasso"
        device 0
    }

    ctl.dc_elite {
        type hw
        card "[iBasso"
    }
  '';
}
