{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-1";

  roles.router = {
    enable = true;
    wirelessSecretsFile = "/run/secrets/wpa_supplicant.env";
    wan = {
      ssid = "WAN-4G";
      pskEnvVar = "WAN_4G_PSK";
      priority = 10;
    };
  };

  roles.k3s.masterWorker = {
    enable = true;
    nodeIP = "10.10.0.10";
    apiAddress = "10.10.0.10";
    clusterInit = true;
    nodeLabels = [ "role=infra" ];
  };

  roles.hardening.enable = true;
}
