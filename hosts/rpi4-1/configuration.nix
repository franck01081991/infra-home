{ topology, ... }:
let
  host = topology.hosts.rpi4-1;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-1";

  roles.router = {
    enable = host.router;
    wirelessSecretsFile = "/run/secrets/wpa_supplicant.env";
    wan = {
      ssid = "WAN-4G";
      pskEnvVar = "WAN_4G_PSK";
      priority = 10;
    };
    vlans = topology.vlans;
  };

  roles.k3s.masterWorker = {
    enable = host.k3s.role == "master-worker";
    nodeIP = host.addresses.infra;
    apiAddress = topology.k3s.apiAddress;
    clusterInit = host.k3s.clusterInit;
    serverAddr = if host.k3s.clusterInit then null else topology.k3s.serverAddr;
    nodeLabels = host.k3s.nodeLabels;
  };

  roles.hardening.enable = true;
}
