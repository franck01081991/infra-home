{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-1";

  networking.interfaces.eth0.useDHCP = lib.mkForce false;

  networking.vlans."eth0.10" = {
    id = 10;
    interface = "eth0";
  };

  networking.interfaces."eth0.10".ipv4.addresses = [
    {
      address = "10.10.0.10";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = lib.mkForce "10.10.0.1";
}
