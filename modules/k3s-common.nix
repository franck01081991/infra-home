{ config, pkgs, lib, ... }:

let
  k3sTokenFile = "/etc/k3s/token";
  masterIp = "10.10.0.10";
in {
  environment.systemPackages = with pkgs; [
    k3s
    kubectl
    git
  ];

  networking.firewall.allowedTCPPorts = [ 6443 ];

  services.k3s = {
    enable = true;
    package = pkgs.k3s;
    tokenFile = k3sTokenFile;
    role = "server";

    clusterInit = config.networking.hostName == "rpi4-1";

    serverAddr = lib.mkIf (config.networking.hostName != "rpi4-1")
      "https://${masterIp}:6443";

    extraFlags =
      let
        nodeIP =
          if config.networking.hostName == "rpi4-1" then "10.10.0.10"
          else if config.networking.hostName == "rpi4-2" then "10.10.0.11"
          else "10.10.0.12";
      in
      [
        "--node-ip=${nodeIP}"
        "--tls-san=${masterIp}"
      ]
      ++ lib.optionals (config.networking.hostName == "rpi3a-ctl") [
        "--node-taint=node-role.kubernetes.io/control-plane=true:NoSchedule"
      ];
  };
}
