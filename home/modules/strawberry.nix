{ pkgs, ... }:

{
  home.packages = [ pkgs.strawberry ];

  # Strawberry's device choice is intentionally not hardcoded here:
  # ALSA card identifiers can differ. Use dc-elite-alsa-config after
  # first boot, then select the "dc_elite" ALSA hardware device in
  # Strawberry.
}
