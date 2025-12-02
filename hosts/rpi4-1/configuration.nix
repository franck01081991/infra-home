{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "rpi4-1";

  networking.interfaces.eth0.useDHCP = lib.mkForce false;
}
