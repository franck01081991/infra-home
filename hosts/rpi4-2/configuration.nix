{ topology, ... }:
let
  host = topology.hosts.rpi4-2;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-2";

  roles.k3s.masterWorker = {
    enable = host.k3s.role == "master-worker";
    nodeIP = host.addresses.infra;
    apiAddress = topology.k3s.apiAddress;
    serverAddr = topology.k3s.serverAddr;
    nodeLabels = host.k3s.nodeLabels;
  };

  roles.hardening.enable = true;
}
