{ topology, ... }:
let
  host = topology.hosts.rpi3a-ctl;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi3a-ctl";

  roles.k3s.controlPlaneOnly = {
    enable = host.k3s.role == "control-plane-only";
    nodeIP = host.addresses.infra;
    apiAddress = topology.k3s.apiAddress;
    serverAddr = topology.k3s.serverAddr;
    nodeLabels = host.k3s.nodeLabels;
    nodeTaints = host.k3s.nodeTaints;
  };

  roles.hardening.enable = true;
}
