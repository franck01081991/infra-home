{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-2";

  roles.k3s.masterWorker = {
    enable = true;
    nodeIP = "10.10.0.11";
    apiAddress = "10.10.0.10";
    serverAddr = "https://10.10.0.10:6443";
    nodeLabels = [ "role=infra" ];
  };

  roles.hardening.enable = true;
}
