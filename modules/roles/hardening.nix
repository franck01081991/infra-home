{ config, lib, ... }:
let
  cfg = config.roles.hardening;

  adminUser = cfg.adminUser;

in {
  options.roles.hardening = {
    enable = lib.mkEnableOption "Hardening SSH et comptes";

    adminUser = lib.mkOption {
      type = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "franck";
            description = "Nom du compte administrateur.";
          };

          isNormalUser = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Définit s'il s'agit d'un utilisateur normal.";
          };

          extraGroups = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "wheel" ];
            description = "Groupes supplémentaires.";
          };

          authorizedKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "ssh-ed25519 AAAA...cle_publique_a_remplacer..." ];
            description = "Clés SSH autorisées.";
          };
        };
      };
      default = { };
      description = "Utilisateur admin et ses clés.";
    };

    sshd = lib.mkOption {
      type = lib.types.submodule {
        options = {
          permitRootLogin = lib.mkOption {
            type = lib.types.str;
            default = "no";
            description = "Valeur PermitRootLogin.";
          };

          passwordAuthentication = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Active l'authentification par mot de passe.";
          };

          kbdInteractiveAuthentication = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Active l'authentification clavier interactif.";
          };

          allowAgentForwarding = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Autorise l'AgentForwarding SSH.";
          };

          allowTcpForwarding = lib.mkOption {
            type = lib.types.str;
            default = "no";
            description = "Valeur AllowTcpForwarding.";
          };

          loginGraceTime = lib.mkOption {
            type = lib.types.str;
            default = "30s";
            description = "LoginGraceTime.";
          };

          maxAuthTries = lib.mkOption {
            type = lib.types.int;
            default = 3;
            description = "MaxAuthTries.";
          };
        };
      };
      default = { };
      description = "Paramètres OpenSSH server.";
    };

    sudoPasswordless = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Autoriser sudo sans mot de passe pour wheel.";
    };

    persistentJournal = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Activer le stockage persistant du journal.";
    };

    journalMaxUse = lib.mkOption {
      type = lib.types.str;
      default = "300M";
      description = "Limite de stockage pour journald.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = cfg.sshd.permitRootLogin;
        PasswordAuthentication = cfg.sshd.passwordAuthentication;
        KbdInteractiveAuthentication = cfg.sshd.kbdInteractiveAuthentication;
        X11Forwarding = false;
        AllowAgentForwarding = cfg.sshd.allowAgentForwarding;
        AllowTcpForwarding = cfg.sshd.allowTcpForwarding;
        LoginGraceTime = cfg.sshd.loginGraceTime;
        MaxAuthTries = cfg.sshd.maxAuthTries;
      };
    };

    users.users.${adminUser.name} = {
      isNormalUser = adminUser.isNormalUser;
      extraGroups = adminUser.extraGroups;
      # Remplacez la clé publique ci-dessous par la vôtre ; les connexions root ou par mot de passe sont désactivées.
      openssh.authorizedKeys.keys = adminUser.authorizedKeys;
    };

    security.sudo = {
      enable = true;
      wheelNeedsPassword = !cfg.sudoPasswordless;
    };

    services.journald.extraConfig = lib.mkIf cfg.persistentJournal ''
      Storage=persistent
      Compress=yes
      SystemMaxUse=${cfg.journalMaxUse}
    '';
  };
}
