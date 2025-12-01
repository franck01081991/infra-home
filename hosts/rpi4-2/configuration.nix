{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-2";

  networking.interfaces.eth0.useDHCP = false;

  networking.vlans."eth0.10" = {
    id = 10;
    interface = "eth0";
  };

  networking.interfaces."eth0.10".ipv4.addresses = [{
    address = "10.10.0.11";
    prefixLength = 24;
  }];

  networking.defaultGateway = "10.10.0.1";
}
