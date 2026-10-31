{ ... }:

{
  # These modules target Framework-specific hardware and must not be imported
  # by a different laptop's Home Manager configuration.
  imports = [
    ../../home/modules/dc-elite.nix
    ../../home/modules/display-color.nix
  ];
}
