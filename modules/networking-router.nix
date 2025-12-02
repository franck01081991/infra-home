{ config, pkgs, lib, ... }:

{
  networking.wireless.enable = true;
  networking.wireless.secretsFile = "/run/secrets/wpa_supplicant.env";
  networking.wireless.networks."WAN-4G" = {
    # Le PSK doit être injecté au runtime via /run/secrets/wpa_supplicant.env
    # (ex: produit par sops-nix ou un drop-in systemd). Ne jamais le mettre
    # dans le store Nix.
    psk = "@WAN_4G_PSK@";
    priority = 10;
  };
  networking.interfaces.wlan0.useDHCP = true;

  networking.interfaces.eth0.useDHCP = false;

  networking.vlans = {
    "eth0.10" = { id = 10; interface = "eth0"; };
    "eth0.20" = { id = 20; interface = "eth0"; };
    "eth0.30" = { id = 30; interface = "eth0"; };
    "eth0.40" = { id = 40; interface = "eth0"; };
  };

  networking.interfaces."eth0.10".ipv4.addresses = [{
    address = "10.10.0.1";
    prefixLength = 24;
  }];
  networking.interfaces."eth0.20".ipv4.addresses = [{
    address = "10.20.0.1";
    prefixLength = 24;
  }];
  networking.interfaces."eth0.30".ipv4.addresses = [{
    address = "10.30.0.1";
    prefixLength = 24;
  }];
  networking.interfaces."eth0.40".ipv4.addresses = [{
    address = "10.40.0.1";
    prefixLength = 24;
  }];

  networking.nat = {
    enable = true;
    externalInterface = "wlan0";
    internalInterfaces = [ "eth0.10" "eth0.20" "eth0.30" "eth0.40" ];
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "eth0.10,eth0.20,eth0.30,eth0.40";
      dhcp-range = [
        "set:infra,10.10.0.100,10.10.0.200,12h"
        "set:pro,10.20.0.100,10.20.0.200,12h"
        "set:perso,10.30.0.100,10.30.0.200,12h"
        "set:iot,10.40.0.100,10.40.0.200,12h"
      ];
      dhcp-option = [
        "tag:infra,option:router,10.10.0.1"
        "tag:pro,option:router,10.20.0.1"
        "tag:perso,option:router,10.30.0.1"
        "tag:iot,option:router,10.40.0.1"
      ];
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

            iif "lo" accept
            ct state { established, related } accept

            ip saddr { 10.10.0.0/24,10.20.0.0/24,10.30.0.0/24,10.40.0.0/24 } icmp type echo-request accept

            udp dport { 53,67,68 } accept
            tcp dport 53 accept

            iif "eth0.10" tcp dport { 22,6443 } accept

            tcp dport { 80,443 } accept

            reject with icmpx type admin-prohibited
          }

          chain forward {
            type filter hook forward priority 0;

            ct state { established, related } accept

            iif "eth0.10" accept

            iif "eth0.20" oif "wlan0" accept
            iif "eth0.20" oif "eth0.10" tcp dport { 80,443,8443 } accept

            iif "eth0.30" oif "wlan0" accept
            iif "eth0.30" oif "eth0.10" tcp dport 443 accept

            iif "eth0.40" oif "wlan0" accept
            iif "eth0.40" oif "eth0.10" tcp dport { 443,8123,1883 } accept

            reject with icmpx type admin-prohibited
          }

          chain output {
            type filter hook output priority 0;
            accept
          }
        '';
      };
    };
  };
}
