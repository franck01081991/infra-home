{
  description =
    "Infra maison : NixOS + k3s HA + VLAN + OpenBao + téléphones workers ARM";

  inputs = { nixpkgs.url = "nixpkgs/nixos-24.05"; };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
      phoneDevices = import ./phone/devices.nix;
    in {
      nixosModules = {
        role-router = import ./modules/roles/router.nix;
        role-k3s-master-worker = import ./modules/roles/k3s-master-worker.nix;
        role-k3s-control-plane-only =
          import ./modules/roles/k3s-control-plane-only.nix;
        role-hardening = import ./modules/roles/hardening.nix;
      };

      nixosConfigurations = {
        rpi4-1 = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/topology.nix
            ./modules/wireless-secrets-compat.nix
            ./hosts/rpi4-1/configuration.nix
            ./modules/networking-common.nix
            self.nixosModules.role-router
            self.nixosModules.role-k3s-master-worker
            self.nixosModules.role-hardening
          ];
        };

        rpi4-2 = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/topology.nix
            ./modules/wireless-secrets-compat.nix
            ./hosts/rpi4-2/configuration.nix
            ./modules/networking-common.nix
            self.nixosModules.role-k3s-master-worker
            self.nixosModules.role-hardening
          ];
        };

        rpi3a-ctl = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/topology.nix
            ./modules/wireless-secrets-compat.nix
            ./hosts/rpi3a-ctl/configuration.nix
            ./modules/networking-common.nix
            self.nixosModules.role-k3s-control-plane-only
            self.nixosModules.role-hardening
          ];
        };
      };

      packages.${system} = import ./phone/flake-part-phone.nix {
        inherit pkgs;
        devices = phoneDevices;
      };

      devShells.${system}.default = import ./nix/devshell.nix { inherit pkgs; };

      apps.${system}.render = {
        type = "app";
        program = pkgs.writeShellApplication {
          name = "render";
          runtimeInputs = [ pkgs.kustomize ];
          text = ''
            env="''${ENV:-''${1:-review}}"
            "${./scripts/render-desired-state.sh}" "$env"
          '';
        };
      };
    };
}
