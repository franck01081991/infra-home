{ config, pkgs, lib, ... }:
let
  cfg = config.roles.k3s.controlPlaneOnly;

  apiAddress = cfg.apiAddress or cfg.nodeIP;

  nodeLabelArgs =
    lib.concatMap (label: [ "--node-label" label ]) cfg.nodeLabels;

  taintArgs = lib.concatMap (taint: [ "--node-taint" taint ]) cfg.nodeTaints;

  extraArgs = [ "--node-ip=${cfg.nodeIP}" "--disable-agent" ]
    ++ lib.optional (apiAddress != null) "--tls-san=${apiAddress}"
    ++ nodeLabelArgs ++ taintArgs;

in
{
  options.roles.k3s.controlPlaneOnly = {
    enable = lib.mkEnableOption "k3s control-plane only role";

    nodeIP = lib.mkOption {
      type = lib.types.str;
      description = "Adresse IP à annoncer pour le nœud.";
    };

    apiAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description =
        "Adresse à ajouter en SAN TLS pour l'API (par défaut nodeIP).";
    };

    serverAddr = lib.mkOption {
      type = lib.types.str;
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
      default = [ "node-role.kubernetes.io/control-plane=true:NoSchedule" ];
      description = "Taints appliqués via extraFlags (--node-taint).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ k3s kubectl git ];

    networking.firewall.allowedTCPPorts = [ 6443 ];

    services.k3s = {
      enable = true;
      package = pkgs.k3s;
      inherit (cfg) tokenFile serverAddr;
      role = "server";

      clusterInit = false;

      extraFlags = lib.concatStringsSep " " extraArgs;
    };
  };
}
