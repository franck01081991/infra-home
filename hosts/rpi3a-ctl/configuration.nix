{ topology, ... }:
let
  host = topology.hosts.rpi3a-ctl;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi3a-ctl";

  roles = {
    k3s.controlPlaneOnly = {
      enable = host.k3s.role == "control-plane-only";
      nodeIP = host.addresses.infra;
      inherit (topology.k3s) apiAddress serverAddr;
      inherit (host.k3s) nodeLabels nodeTaints;
    };

    hardening.enable = true;
  };
}
