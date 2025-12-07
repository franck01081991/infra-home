{ topology, ... }:
let
  host = topology.hosts.rpi4-2;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-2";

  roles = {
    k3s.masterWorker = {
      enable = host.k3s.role == "master-worker";
      nodeIP = host.addresses.infra;
      inherit (topology.k3s) apiAddress serverAddr;
      inherit (host.k3s) nodeLabels;
    };

    hardening.enable = true;
  };
}
