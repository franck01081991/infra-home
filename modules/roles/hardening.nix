{ config, lib, ... }:
let
  cfg = config.roles.hardening;
  inherit (cfg) adminUser;

in
{
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
            default = [
              # ⚠️  IMPORTANT: Remplacez cette clé par votre clé publique SSH !
              # Générez une clé avec: ssh-keygen -t ed25519 -C "votre.email@example.com"
              # Puis copiez le contenu de ~/.ssh/id_ed25519.pub ici
              "ssh-ed25519 AAAA...REMPLACEZ_PAR_VOTRE_CLE_PUBLIQUE...votre.email@example.com"
            ];
            description =
              "Clés SSH autorisées. DOIT être remplacé par votre clé publique !";
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
      inherit (adminUser) isNormalUser extraGroups;
      # ⚠️  CRITIQUE: Vous DEVEZ remplacer la clé SSH par défaut dans la configuration !
      # Les connexions root et par mot de passe sont désactivées pour la sécurité.
      # Voir: modules/roles/hardening.nix ligne 38 pour modifier la clé par défaut
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
