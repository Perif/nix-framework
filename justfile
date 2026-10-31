host := "framework-pro"

# Build without activating.
build:
    nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel --no-link

# Test a configuration without making it the boot default.
test:
    sudo nixos-rebuild test --flake .#{{host}}

# Activate immediately and make this the boot default.
switch:
    sudo nixos-rebuild switch --flake .#{{host}}

# Set the configuration for the next boot without activating it now.
boot:
    sudo nixos-rebuild boot --flake .#{{host}}

# Compare the running and proposed system closures.
diff:
    #!/usr/bin/env bash
    set -euo pipefail
    new=$(nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel --no-link --print-out-paths)
    nix run nixpkgs#nvd -- diff /run/current-system "$new"

# Validate all configured flake checks (may be expensive).
check:
    nix flake check

# Update flake inputs; review the resulting lock-file diff before activation.
update:
    nix flake update

# Update only the Nixpkgs input used by Sublime Text and Sublime Merge.
update-sublime:
    nix flake update nixpkgs-sublime

# Format Nix files through the flake formatter.
fmt:
    nix fmt

# Show available commands.
help:
    just --list
