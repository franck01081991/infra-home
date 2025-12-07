{ topology, ... }:
let
  host = topology.hosts.rpi4-1;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-1";

  roles = {
    router = {
      enable = host.router;
      wirelessSecretsFile = "/run/secrets/wpa_supplicant.env";
      wan = {
        ssid = "WAN-4G";
        pskEnvVar = "WAN_4G_PSK";
        priority = 10;
      };
      inherit (topology) vlans;
    };

    k3s.masterWorker = {
      enable = host.k3s.role == "master-worker";
      nodeIP = host.addresses.infra;
      inherit (topology.k3s) apiAddress;
      inherit (host.k3s) clusterInit nodeLabels;
      serverAddr = if host.k3s.clusterInit then null else topology.k3s.serverAddr;
    };

    hardening.enable = true;
  };
}
