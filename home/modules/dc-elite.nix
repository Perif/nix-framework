{ pkgs, ... }:

let
  # Runtime detection is preferable to hardcoding an ALSA card index.
  # The helper emits an ALSA `hw` device stanza for strict direct access.
  #
  # Packaged with writeShellApplication and installed through home.packages
  # so it is on PATH. Neither NixOS nor Home Manager adds ~/.local/bin to
  # PATH by default, which is where the previous home.file version lived.
  # writeShellApplication supplies the shebang, `set -euo pipefail`, and
  # runs shellcheck at build time.
  dc-elite-alsa-config = pkgs.writeShellApplication {
    name = "dc-elite-alsa-config";

    runtimeInputs = with pkgs; [
      alsa-utils
      gawk
    ];

    # The awk program legitimately uses $0 inside single quotes.
    excludeShellChecks = [ "SC2016" ];

    text = ''
      card="$(
        aplay -l 2>/dev/null |
          awk '
            /iBasso|DC-Elite|DC Elite/ {
              if (match($0, /card ([0-9]+): ([^ ]+)/, a)) {
                print a[2]
                exit
              }
            }' || true
      )"

      if [[ -z "$card" ]]; then
        echo "DC-Elite not found. Connect it and run: aplay -l" >&2
        exit 1
      fi

      echo "Detected ALSA card id: $card"
      echo
      cat <<EOF
      pcm.dc_elite {
          type hw
          card $card
          device 0
      }

      ctl.dc_elite {
          type hw
          card $card
      }
      EOF
    '';
  };
in
{
  home.packages = [ dc-elite-alsa-config ];
}
