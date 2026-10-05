{ pkgs }:
let
  base = with pkgs; [
    git
    just
    shellcheck
    shfmt
  ];
  shell = packages: pkgs.mkShell { packages = base ++ packages; };
in
{
  default = shell [ ];
  c = shell (
    with pkgs;
    [
      gcc
      gnumake
      cmake
      ninja
      pkg-config
      gdb
    ]
  );
  python = shell (
    with pkgs;
    [
      python3
      uv
      basedpyright
      ruff
    ]
  );
  go = shell (
    with pkgs;
    [
      go
      gopls
      delve
      golangci-lint
    ]
  );
  rust = shell (
    with pkgs;
    [
      rustc
      cargo
      rust-analyzer
      rustfmt
      clippy
      pkg-config
    ]
  );
  nodejs = shell (with pkgs; [ nodejs ]);
  nix = shell (
    with pkgs;
    [
      nixd
      nixfmt
    ]
  );
}
