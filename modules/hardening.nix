{ config, pkgs, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = "no";
      LoginGraceTime = "30s";
      MaxAuthTries = 3;
    };
  };

  users.users.franck = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA...cle_publique_a_remplacer..."
    ];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=300M
  '';
}
