{ config, lib, ... }:
let
  cfg = config.roles.router;

  mkIfaceName = id: "${cfg.lanInterface}.${toString id}";

  wanNetwork = {
    priority = cfg.wan.priority;
    psk = "@${cfg.wan.pskEnvVar}@";
  };

  wirelessNetworks = lib.mkMerge [
    { "${cfg.wan.ssid}" = wanNetwork; }
    cfg.wirelessAdditionalNetworks
  ];

  networks = builtins.map (
    network: network // {
      iface = mkIfaceName network.id;
    }
  ) cfg.vlans;

  vlansByName = builtins.listToAttrs (map (n: {
    name = n.name;
    value = n;
  }) networks);

  mkForwardRule = source: rule:
    let
      targetInterface = if rule.target == "wan" then cfg.wanInterface else (vlansByName.${rule.target}).iface;
      tcpPorts = lib.concatStringsSep "," (map toString rule.tcpPorts);
      udpPorts = lib.concatStringsSep "," (map toString rule.udpPorts);
      tcpCondition = lib.optionalString (rule.tcpPorts != []) " tcp dport { ${tcpPorts} }";
      udpCondition = lib.optionalString (rule.udpPorts != []) " udp dport { ${udpPorts} }";
      portCondition = lib.concatStringsSep "" [ tcpCondition udpCondition ];
      protoCondition = if rule.allowAll then "" else portCondition;
    in
    "    iif \"${source.iface}\" oif \"${targetInterface}\"${protoCondition} accept";

  mkIngressRule = network:
    let
      tcpPorts = lib.concatStringsSep "," (map toString network.ingressTcpPorts);
    in
    lib.optionalString (network.ingressTcpPorts != [])
      "    iif \"${network.iface}\" tcp dport { ${tcpPorts} } accept";

  mkForwardRules = network:
    builtins.concatStringsSep "\n" (map (rule: mkForwardRule network rule) network.forwardRules);

  mkAddresses = network:
    map (addr: { inherit (addr) address prefixLength; }) network.routerAddresses;

  subnets = map (network: network.subnet) networks;

  dhcpRanges = map (network: network.dhcpRange) networks;

  dhcpOptions = map (
    network:
      let
        gateway = builtins.elemAt network.routerAddresses network.defaultGatewayIndex;
      in
      "tag:${network.name},option:router,${gateway.address}"
  ) networks;

  nftablesInputRules = builtins.concatStringsSep "\n" (
    [
      "    iif \"lo\" accept"
      "    ct state { established, related } accept"
      ""
      "    ip saddr { ${lib.concatStringsSep "," subnets} } icmp type echo-request accept"
      ""
      "    udp dport { 53,67,68 } accept"
      "    tcp dport 53 accept"
    ]
    ++ map mkIngressRule networks
    ++ [
      ""
      "    tcp dport { 80,443 } accept"
      ""
      "    reject with icmpx type admin-prohibited"
    ]
  );

  nftablesForwardRules = builtins.concatStringsSep "\n" (
    [
      "    ct state { established, related } accept"
    ]
    ++ lib.flatten (map (network: [ (mkForwardRules network) ]) networks)
    ++ [
      ""
      "    reject with icmpx type admin-prohibited"
    ]
  );

  vlanInterfaces = map (network: network.iface) networks;

in {
  options.roles.router = {
    enable = lib.mkEnableOption "router role";

    wanInterface = lib.mkOption {
      type = lib.types.str;
      default = "wlan0";
      description = "Interface réseau externe (WAN).";
    };

    wan = lib.mkOption {
      description = "Paramètres du réseau Wi-Fi WAN (SSID et PSK injecté par secretsFile).";
      default = {};
      type = lib.types.submodule {
        options = {
          ssid = lib.mkOption {
            type = lib.types.str;
            default = "WAN-4G";
            description = "SSID du Wi-Fi WAN.";
          };

          pskEnvVar = lib.mkOption {
            type = lib.types.str;
            default = "WAN_4G_PSK";
            description = "Nom de la variable d'environnement contenant le PSK (dans secretsFile).";
          };

          priority = lib.mkOption {
            type = lib.types.int;
            default = 10;
            description = "Priorité wpa_supplicant du réseau WAN.";
          };
        };
      };
    };

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "Interface réseau interne sur laquelle les VLANs sont attachés.";
    };

    wirelessSecretsFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets/wpa_supplicant.env";
      description = "Chemin du fichier de secrets pour wpa_supplicant.";
    };

    wirelessAdditionalNetworks = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Réseaux Wi-Fi supplémentaires à ajouter en plus du WAN (clé = SSID).";
    };

    vlans = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ name, ... }: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "Nom logique du VLAN.";
          };

          id = lib.mkOption {
            type = lib.types.int;
            description = "Identifiant VLAN.";
          };

          subnet = lib.mkOption {
            type = lib.types.str;
            description = "CIDR du réseau.";
          };

          routerAddresses = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                address = lib.mkOption {
                  type = lib.types.str;
                  description = "Adresse IPv4 du routeur sur ce VLAN.";
                };

                prefixLength = lib.mkOption {
                  type = lib.types.int;
                  description = "Longueur de préfixe.";
                };
              };
            });
            description = "Adresses IPv4 du routeur sur ce VLAN.";
          };

          defaultGatewayIndex = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "Index de l'adresse utilisée comme passerelle DHCP.";
          };

          dhcpRange = lib.mkOption {
            type = lib.types.str;
            description = "Plage DHCP dnsmasq (syntaxe dnsmasq).";
          };

          ingressTcpPorts = lib.mkOption {
            type = lib.types.listOf lib.types.int;
            default = [ ];
            description = "Ports TCP autorisés en entrée sur ce VLAN.";
          };

          forwardRules = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                target = lib.mkOption {
                  type = lib.types.str;
                  description = "Nom du VLAN cible ou 'wan'.";
                };

                tcpPorts = lib.mkOption {
                  type = lib.types.listOf lib.types.int;
                  default = [ ];
                  description = "Ports TCP autorisés vers la cible (vide = aucun sauf si allowAll).";
                };

                udpPorts = lib.mkOption {
                  type = lib.types.listOf lib.types.int;
                  default = [ ];
                  description = "Ports UDP autorisés vers la cible (vide = aucun sauf si allowAll).";
                };

                allowAll = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Autoriser tout le trafic vers la cible (ignore les listes de ports).";
                };
              };
            });
            default = [ ];
            description = "Règles de forwarding (VLAN → cible).";
          };
        };
      }));
      description = "Définition des VLANs gérés par le routeur.";
      default = [
        {
          name = "infra";
          id = 10;
          subnet = "10.10.0.0/24";
          routerAddresses = [
            { address = "10.10.0.1"; prefixLength = 24; }
            { address = "10.10.0.10"; prefixLength = 24; }
          ];
          defaultGatewayIndex = 0;
          dhcpRange = "set:infra,10.10.0.100,10.10.0.200,12h";
          ingressTcpPorts = [ 22 6443 ];
          forwardRules = [
            { target = "wan"; allowAll = true; tcpPorts = [ ]; udpPorts = [ ]; }
          ];
        }
        {
          name = "pro";
          id = 20;
          subnet = "10.20.0.0/24";
          routerAddresses = [ { address = "10.20.0.1"; prefixLength = 24; } ];
          defaultGatewayIndex = 0;
          dhcpRange = "set:pro,10.20.0.100,10.20.0.200,12h";
          forwardRules = [
            { target = "wan"; allowAll = true; tcpPorts = [ ]; udpPorts = [ ]; }
            { target = "infra"; tcpPorts = [ 80 443 8443 ]; udpPorts = [ ]; allowAll = false; }
          ];
        }
        {
          name = "perso";
          id = 30;
          subnet = "10.30.0.0/24";
          routerAddresses = [ { address = "10.30.0.1"; prefixLength = 24; } ];
          defaultGatewayIndex = 0;
          dhcpRange = "set:perso,10.30.0.100,10.30.0.200,12h";
          forwardRules = [
            { target = "wan"; allowAll = true; tcpPorts = [ ]; udpPorts = [ ]; }
            { target = "infra"; tcpPorts = [ 443 ]; udpPorts = [ ]; allowAll = false; }
          ];
        }
        {
          name = "iot";
          id = 40;
          subnet = "10.40.0.0/24";
          routerAddresses = [ { address = "10.40.0.1"; prefixLength = 24; } ];
          defaultGatewayIndex = 0;
          dhcpRange = "set:iot,10.40.0.100,10.40.0.200,12h";
          forwardRules = [
            { target = "wan"; allowAll = true; tcpPorts = [ ]; udpPorts = [ ]; }
            { target = "infra"; tcpPorts = [ 443 8123 1883 ]; udpPorts = [ ]; allowAll = false; }
          ];
        }
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    networking.wireless.enable = true;
    networking.wireless.secretsFile = cfg.wirelessSecretsFile;
    networking.wireless.networks = wirelessNetworks;

    networking.vlans = builtins.listToAttrs (map (network: {
      name = network.iface;
      value = {
        id = network.id;
        interface = cfg.lanInterface;
      };
    }) networks);

    networking.interfaces = lib.mkMerge [
      {
        "${cfg.wanInterface}".useDHCP = true;
        "${cfg.lanInterface}".useDHCP = false;
      }
      (builtins.listToAttrs (map (network: {
        name = network.iface;
        value = {
          ipv4.addresses = mkAddresses network;
        };
      }) networks))
    ];

    networking.nat = {
      enable = true;
      externalInterface = cfg.wanInterface;
      internalInterfaces = vlanInterfaces;
    };

    services.dnsmasq = {
      enable = true;
      settings = {
        interface = lib.concatStringsSep "," vlanInterfaces;
        dhcp-range = dhcpRanges;
        dhcp-option = dhcpOptions;
        server = [ "1.1.1.1" "9.9.9.9" ];
      };
    };

    networking.firewall.enable = false;

    networking.nftables = {
      enable = true;
      tables = {
        inet-filter = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority 0;

${nftablesInputRules}
            }

            chain forward {
              type filter hook forward priority 0;

${nftablesForwardRules}
            }

            chain output {
              type filter hook output priority 0;
              accept
            }
          '';
        };
      };
    };
  };
}
