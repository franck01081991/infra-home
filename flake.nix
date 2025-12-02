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
    nixosModules = {
      role-router = import ./modules/roles/router.nix;
      role-k3s-master-worker = import ./modules/roles/k3s-master-worker.nix;
      role-k3s-control-plane-only = import ./modules/roles/k3s-control-plane-only.nix;
      role-hardening = import ./modules/roles/hardening.nix;
    };

    nixosConfigurations = {
      rpi4-1 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules/wireless-secrets-compat.nix
          ./hosts/rpi4-1/configuration.nix
          ./modules/networking-common.nix
          self.nixosModules.role-router
          self.nixosModules.role-k3s-master-worker
          self.nixosModules.role-hardening
          {
            roles.router.enable = true;

            roles.k3s.masterWorker = {
              enable = true;
              nodeIP = "10.10.0.10";
              apiAddress = "10.10.0.10";
              clusterInit = true;
              nodeLabels = [ "role=infra" ];
            };

            roles.hardening.enable = true;
          }
        ];
      };

      rpi4-2 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules/wireless-secrets-compat.nix
          ./hosts/rpi4-2/configuration.nix
          ./modules/networking-common.nix
          self.nixosModules.role-k3s-master-worker
          self.nixosModules.role-hardening
          {
            roles.k3s.masterWorker = {
              enable = true;
              nodeIP = "10.10.0.11";
              apiAddress = "10.10.0.10";
              serverAddr = "https://10.10.0.10:6443";
              nodeLabels = [ "role=infra" ];
            };

            roles.hardening.enable = true;
          }
        ];
      };

      rpi3a-ctl = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules/wireless-secrets-compat.nix
          ./hosts/rpi3a-ctl/configuration.nix
          ./modules/networking-common.nix
          self.nixosModules.role-k3s-control-plane-only
          self.nixosModules.role-hardening
          {
            roles.k3s.controlPlaneOnly = {
              enable = true;
              nodeIP = "10.10.0.12";
              apiAddress = "10.10.0.10";
              serverAddr = "https://10.10.0.10:6443";
            };

            roles.hardening.enable = true;
          }
        ];
      };
    };

    packages.${system} =
      import ./phone/flake-part-phone.nix {
        inherit pkgs;
        devices = phoneDevices;
      };

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
