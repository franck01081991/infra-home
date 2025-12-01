{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi3a-ctl";

  networking.wireless.enable = true;
  networking.wireless.networks."INFRA-K3S" = {
    psk = "motdepasse-infra";
    priority = 10;
  };

  networking.interfaces.wlan0.ipv4.addresses = [{
    address = "10.10.0.12";
    prefixLength = 24;
  }];

  networking.defaultGateway = "10.10.0.1";
}
