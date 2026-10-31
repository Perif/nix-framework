# NixOS Repository Instructions

## Environment
- Framework Laptop 13 Pro (Intel)
- NixOS 26.05 with flakes
- KDE Plasma 6 / Wayland
- Home Manager integrated with NixOS
- LUKS2 encrypted storage

## Repository structure
- flake.nix: Flake entry point
- settings.nix: Host and feature configuration
- hosts/framework-pro/: Machine configuration
- modules/nixos/: System-level modules
- home/modules/: Home Manager modules
- home/user/default.nix: User module imports
- tests/: Validation tests

## Engineering rules
- Prefer declarative Nix configurations.
- Follow the existing repository conventions.
- Reuse existing modules before creating new ones.
- Minimize additional dependencies.
- Avoid unnecessary changes to flake.lock.
- Never modify encryption, bootloader, or partitioning
  without explicit permission.
- Do not run nixos-rebuild switch or destructive commands
  without explicit permission.
- Never commit secrets or authentication tokens.

## Validation
- Run nix flake check when practical.
- Evaluate changes before applying them.
- Review git diff.
- Explain changes, test results, and remaining risks.
