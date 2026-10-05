{
  description = "Project-local development tools";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs = { nixpkgs, ... }: {
    devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
      system: import ./shells.nix { pkgs = import nixpkgs { inherit system; }; }
    );
  };
}
