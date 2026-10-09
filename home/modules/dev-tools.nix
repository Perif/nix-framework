{
  lib,
  pkgs,
  settings,
  ...
}:

let
  features = settings.features;
  languages = features.languageTools;

  corePackages = with pkgs; [
    gh

    ripgrep
    fd
    jq
    yq
    tree
    unzip
    zip

    just
    shellcheck
    shfmt

    podman-compose

    btop
    htop
    tmux
  ];

  languagePackages =
    lib.optionals languages.c (
      with pkgs;
      [
        gcc
        gnumake
        cmake
        ninja
        pkg-config
      ]
    )
    ++ lib.optionals languages.python (
      with pkgs;
      [
        python3
        uv
        basedpyright
        ruff
      ]
    )
    ++ lib.optionals languages.go (
      with pkgs;
      [
        go
        gopls
        delve
        golangci-lint
      ]
    )
    ++ lib.optionals languages.rust (
      with pkgs;
      [
        rustc
        cargo
        rust-analyzer
        rustfmt
        clippy
      ]
    )
    ++ lib.optionals languages.nodejs [ pkgs.nodejs ]
    ++ lib.optionals languages.nix [
      pkgs.nixd
      pkgs.nixfmt
    ];
in
{
  # Keep the common tools small and predictable. Language SDKs can be selected
  # independently in settings.nix, while project-specific versions belong in
  # each project's devShell.
  home.packages = lib.optionals features.devCore corePackages ++ languagePackages;

  programs.fzf = {
    enable = features.devCore;
    enableZshIntegration = features.devCore;
  };

  programs.zoxide = {
    enable = features.devCore;
    enableZshIntegration = features.devCore;
  };

  programs.delta = {
    enable = features.devCore;
    enableGitIntegration = features.devCore;
  };
}
