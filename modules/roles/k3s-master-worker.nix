{ config, pkgs, lib, ... }:
let
  cfg = config.roles.k3s.masterWorker;

  apiAddress = cfg.apiAddress or cfg.nodeIP;

  nodeLabelArgs = lib.concatMap (
    label: [ "--node-label" label ]
  ) cfg.nodeLabels;

  taintArgs = lib.concatMap (
    taint: [ "--node-taint" taint ]
  ) cfg.nodeTaints;

  extraArgs = [
    "--node-ip=${cfg.nodeIP}"
  ]
  ++ lib.optional (apiAddress != null) "--tls-san=${apiAddress}"
  ++ nodeLabelArgs
  ++ taintArgs;

in {
  options.roles.k3s.masterWorker = {
    enable = lib.mkEnableOption "k3s master+worker role";

    nodeIP = lib.mkOption {
      type = lib.types.str;
      description = "Adresse IP à annoncer pour le nœud.";
    };

    apiAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Adresse à ajouter en SAN TLS pour l'API (par défaut nodeIP).";
    };

    clusterInit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Initialise le cluster k3s (server standalone).";
    };

    serverAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Adresse du serveur k3s existant (https://...).";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/k3s/token";
      description = "Chemin du fichier token partagé.";
    };

    nodeLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Labels appliqués via extraFlags (--node-label).";
    };

    nodeTaints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Taints appliqués via extraFlags (--node-taint).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      k3s
      kubectl
      git
    ];

    networking.firewall.allowedTCPPorts = [ 6443 ];

    services.k3s = {
      enable = true;
      package = pkgs.k3s;
      tokenFile = cfg.tokenFile;
      role = "server";

      clusterInit = cfg.clusterInit;

      serverAddr = lib.mkIf (!cfg.clusterInit && cfg.serverAddr != null) cfg.serverAddr;

      extraFlags = lib.concatStringsSep " " extraArgs;
    };
  };
}
