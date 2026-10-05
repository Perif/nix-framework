{ pkgs }:
pkgs.writeShellApplication {
  name = "installer";
  runtimeInputs = with pkgs; [
    python3
    nix
    git
    util-linux
    lvm2
    coreutils
    diffutils
    nixos-install-tools
  ];
  text = ''
    exec python3 ${../scripts/installer}/cli.py "$@"
  '';
}
