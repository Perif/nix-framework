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
      self,
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
      # One Nixpkgs instantiation shared by every x86_64-linux package output.
      linuxPkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    {
      devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        import ./templates/project/shells.nix {
          pkgs = import nixpkgs { inherit system; };
        }
      );
      templates.project = {
        path = ./templates/project;
        description = "Project-local dev shells for C, Python, Go, Rust, Guile, Node.js and Nix";
      };

      # Run the same Disko revision used by this configuration with:
      #   nix run .#disko -- ...
      packages.x86_64-linux.installer = import ./pkgs/installer.nix { pkgs = linuxPkgs; };
      packages.x86_64-linux.webui-bootstrap = import ./pkgs/webui-bootstrap.nix { pkgs = linuxPkgs; };
      packages.x86_64-linux.detect-timezone = import ./pkgs/detect-timezone.nix { pkgs = linuxPkgs; };
      packages.x86_64-linux.disko = disko.packages.x86_64-linux.default;
      packages.x86_64-linux.qobuz-player = linuxPkgs.callPackage ./pkgs/qobuz-player.nix { };
      packages.x86_64-linux.ollaya = linuxPkgs.callPackage ./pkgs/ollaya.nix { };
      packages.x86_64-linux.rea = linuxPkgs.callPackage ./pkgs/rea-with-ghidra.nix { };

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
          rea = import ./tests/rea.nix { inherit pkgs; };
          webui-bootstrap =
            pkgs.runCommand "webui-bootstrap-tests"
              {
                nativeBuildInputs = [ pkgs.python3 ];
              }
              ''
                python3 ${./tests/test_webui_bootstrap.py} --script ${./scripts/webui-bootstrap.py}
                touch "$out"
              '';
          qbz-configuration =
            assert import ./tests/qbz-module.nix { inherit pkgs; };
            pkgs.runCommand "qbz-configuration-tests" { } ''
              touch "$out"
            '';
          bypass-paywalls-clean = import ./tests/bypass-paywalls-clean.nix { inherit pkgs; };
          installer =
            pkgs.runCommand "installer-safety-tests"
              {
                nativeBuildInputs = [ pkgs.python3 ];
              }
              ''
                python3 ${./tests/test_installer.py} --helpers ${./scripts/installer}
                touch "$out"
              '';
          install-timezone =
            pkgs.runCommand "install-timezone-tests"
              {
                nativeBuildInputs = [ pkgs.python3 ];
              }
              ''
                export PYTHONTZPATH="${pkgs.tzdata}/share/zoneinfo"
                python3 ${./tests/test_install_timezone.py} --helper ${./scripts/detect-timezone.py}
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
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          rea-configuration =
            assert import ./tests/rea-config.nix { inherit pkgs; };
            pkgs.runCommand "rea-configuration-tests" { } ''
              touch "$out"
            '';
          touchpad = import ./tests/touchpad.nix { inherit pkgs; };
          software-profiles =
            assert import ./tests/software-profiles.nix {
              configuration = self.nixosConfigurations.${settings.hostname};
              inherit settings;
              inherit (nixpkgs) lib;
            };
            pkgs.runCommand "software-profile-selection-tests" { } ''
              touch "$out"
            '';
          installer-vm = pkgs.testers.runNixOSTest (
            import ./tests/installer-vm.nix { inherit nixpkgs disko; }
          );
          dns-boot = pkgs.testers.runNixOSTest (import ./tests/dns-boot.nix);
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
