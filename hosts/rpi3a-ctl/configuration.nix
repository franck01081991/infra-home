{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi3a-ctl";

  networking.wireless.enable = true;
  networking.wireless.secretsFile = "/run/secrets/wpa_supplicant.env";
  networking.wireless.networks."INFRA-K3S" = {
    # PSK injecté par /run/secrets/wpa_supplicant.env (ex: sops-nix, drop-in
    # systemd). Ne pas le versionner.
    psk = "@INFRA_K3S_PSK@";
    priority = 10;
  };

  networking.interfaces.wlan0.ipv4.addresses = [{
    address = "10.10.0.12";
    prefixLength = 24;
  }];

  networking.defaultGateway = "10.10.0.1";
}
