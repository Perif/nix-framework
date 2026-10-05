{
  description = "Framework Laptop 13 Pro - modular NixOS configuration";

  inputs = {
    # Stable OS/user-space baseline. linuxPackages_latest is selected by the
    # host modules for newer Framework and USB-audio kernel support.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NUR provides the maintained Firefox add-on package set used by
    # Home Manager below. Exact revisions are pinned by flake.lock.
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Signed systemd-boot replacement used after local Secure Boot keys have
    # been created and enrolled. The feature is staged off in settings.nix.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-hardware,
      disko,
      nur,
      lanzaboote,
      ...
    }:
    let
      # Hostname, login user, password and git identity live in one file.
      settings = import ./settings.nix;
    in
    {
      # Run the same Disko revision used by this configuration with:
      #   nix run .#disko -- ...
      packages.x86_64-linux.disko = disko.packages.x86_64-linux.default;
      packages.x86_64-linux.ollaya =
        (import nixpkgs { system = "x86_64-linux"; }).callPackage ./pkgs/ollaya.nix
          { };

      checks = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          hooks = import ./home/modules/git-hooks {
            inherit pkgs;
            inherit (pkgs) lib;
          };
        in
        {
          qbz-configuration =
            assert import ./tests/qbz-module.nix { inherit pkgs; };
            pkgs.runCommand "qbz-configuration-tests" { } ''
              touch "$out"
            '';
          power-management =
            pkgs.runCommand "power-management-tests"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.bash
                  pkgs.shellcheck
                ];
              }
              ''
                shellcheck ${./modules/nixos/scripts/ac-maintenance.sh} ${./modules/nixos/scripts/charge-limit.sh}
                python3 ${./tests/test_power_management.py} \
                  --maintenance ${./modules/nixos/scripts/ac-maintenance.sh} \
                  --charge ${./modules/nixos/scripts/charge-limit.sh}
                touch "$out"
              '';
          git-security =
            pkgs.runCommand "git-security-integration-tests"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.git
                  pkgs.bash
                ];
              }
              ''
                python3 ${./tests/test_git_security.py} \
                  --scanner ${./home/modules/git-hooks/staged-pii-scan.py} \
                  --hook ${hooks.securityPreCommit}/bin/git-security-pre-commit
                touch "$out"
              '';
        }
      );

      nixosConfigurations.${settings.hostname} = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        # Every NixOS module receives `settings` as an argument.
        specialArgs = {
          inherit settings;
        };

        modules = [
          disko.nixosModules.disko
          nixos-hardware.nixosModules.framework-intel-core-ultra-series3
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager

          # Make NUR packages available as pkgs.nur....
          {
            nixpkgs.overlays = [ nur.overlays.default ];
          }

          ./hosts/framework-pro

          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";

              # Expose installation settings to Home Manager modules.
              extraSpecialArgs = {
                inherit settings;
              };

              users.${settings.user.name} = import ./home/user;
            };
          }
        ];
      };
    };
}
