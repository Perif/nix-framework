{ pkgs, ... }:

{
  # Small tools without substantial per-app configuration are grouped
  # instead of creating one module per binary.
  #
  # Not here on purpose:
  # - git-lfs: programs.git.lfs.enable (git.nix) installs it and wires the
  #   filter config.
  # - podman: needs setuid wrappers and sub-UID ranges, so it is a NixOS
  #   service (modules/nixos/containers.nix). Only the compose CLI is a
  #   plain user package.
  home.packages = with pkgs; [
    gh

    ripgrep
    fd
    jq
    yq
    tree
    unzip
    zip

    gcc
    gnumake
    cmake
    ninja
    pkg-config

    python3
    uv
    basedpyright
    ruff

    go
    gopls
    delve
    golangci-lint

    rustc
    cargo
    rust-analyzer
    rustfmt
    clippy

    nodejs

    nixd
    nixfmt

    podman-compose

    btop
    htop
    tmux
  ];
}
