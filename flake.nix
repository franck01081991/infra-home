{
  description = "Infra maison : NixOS + k3s HA + VLAN + OpenBao + téléphones workers ARM";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "aarch64-linux";
    pkgs = import nixpkgs { inherit system; };
    phoneDevices = import ./phone/devices.nix;
  in {
    nixosConfigurations = {
      rpi4-1 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/rpi4-1/configuration.nix
          ./modules/networking-common.nix
          ./modules/networking-router.nix
          ./modules/k3s-common.nix
          ./modules/hardening.nix
        ];
      };

      rpi4-2 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/rpi4-2/configuration.nix
          ./modules/networking-common.nix
          ./modules/k3s-common.nix
          ./modules/hardening.nix
        ];
      };

      rpi3a-ctl = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/rpi3a-ctl/configuration.nix
          ./modules/networking-common.nix
          ./modules/k3s-common.nix
          ./modules/hardening.nix
        ];
      };
    };

    packages.${system} =
      import ./phone/flake-part-phone.nix {
        inherit pkgs;
        devices = phoneDevices;
      };
  };
}
