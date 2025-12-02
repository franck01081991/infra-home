{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi3a-ctl";

  roles.k3s.controlPlaneOnly = {
    enable = true;
    nodeIP = "10.10.0.12";
    apiAddress = "10.10.0.10";
    serverAddr = "https://10.10.0.10:6443";
  };

  roles.hardening.enable = true;
}
