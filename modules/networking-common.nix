{ config, pkgs, ... }:

{
  time.timeZone = "Europe/Paris";

  services.chrony.enable = true;

  networking.nameservers = [ "1.1.1.1" "9.9.9.9" ];

  environment.systemPackages = with pkgs; [
    tcpdump
    mtr
    curl
    wget
    vim
  ];

  system.stateVersion = "24.05";
}
