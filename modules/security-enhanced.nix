# Module de sécurité renforcée pour infra-home
# Ajoute fail2ban, monitoring et autres protections proactives

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security.enhanced;
in

{
  options.security.enhanced = {
    enable = mkEnableOption "sécurité renforcée avec fail2ban et monitoring";
    
    fail2ban = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Activer fail2ban pour la protection contre les attaques par force brute";
      };
      
      banTime = mkOption {
        type = types.str;
        default = "1h";
        description = "Durée de bannissement des IPs suspectes";
      };
      
      maxRetry = mkOption {
        type = types.int;
        default = 3;
        description = "Nombre maximum de tentatives avant bannissement";
      };
    };
    
    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Activer le monitoring système basique";
      };
      
      alertEmail = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Email pour recevoir les alertes (optionnel)";
      };
    };
    
    autoUpdates = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Activer les mises à jour automatiques de sécurité";
      };
      
      schedule = mkOption {
        type = types.str;
        default = "03:00";
        description = "Heure des mises à jour automatiques (format HH:MM)";
      };
    };
  };

  config = mkIf cfg.enable {
    
    # Configuration fail2ban
    services.fail2ban = mkIf cfg.fail2ban.enable {
      enable = true;
      
      # Configuration globale
      bantime = cfg.fail2ban.banTime;
      maxretry = cfg.fail2ban.maxRetry;
      
      # Jails (prisons) pour différents services
      jails = {
        # Protection SSH
        sshd = {
          enabled = true;
          filter = "sshd";
          logpath = "/var/log/auth.log";
          maxretry = cfg.fail2ban.maxRetry;
          bantime = cfg.fail2ban.banTime;
          findtime = "10m";
          action = "iptables[name=SSH, port=ssh, protocol=tcp]";
        };
        
        # Protection contre les scans de ports
        port-scan = {
          enabled = true;
          filter = "port-scan";
          logpath = "/var/log/kern.log";
          maxretry = 1;
          bantime = "24h";
          findtime = "10m";
        };
        
        # Protection nginx (si présent)
        nginx-http-auth = {
          enabled = true;
          filter = "nginx-http-auth";
          logpath = "/var/log/nginx/error.log";
          maxretry = 3;
          bantime = cfg.fail2ban.banTime;
        };
      };
      
      # Filtres personnalisés
      extraPackages = [ pkgs.ipset ];
    };

    # Filtres fail2ban personnalisés
    environment.etc."fail2ban/filter.d/port-scan.conf".text = ''
      [Definition]
      failregex = .*kernel:.*IN=.*OUT=.*SRC=<HOST>.*DPT=(22|23|53|80|110|143|443|993|995).*
      ignoreregex =
    '';

    # Configuration du monitoring système
    systemd.services.system-monitor = mkIf cfg.monitoring.enable {
      description = "Monitoring système basique";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeScript "system-monitor" ''
          #!${pkgs.bash}/bin/bash
          
          # Vérifications système
          HOSTNAME=$(hostname)
          DATE=$(date)
          
          # Vérifier l'espace disque
          DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
          if [ "$DISK_USAGE" -gt 85 ]; then
            echo "ALERTE: Espace disque faible sur $HOSTNAME: $DISK_USAGE%" | logger -t system-monitor
            ${optionalString (cfg.monitoring.alertEmail != null) ''
              echo "ALERTE: Espace disque faible sur $HOSTNAME: $DISK_USAGE%" | \
                mail -s "Alerte infra-home: Espace disque" ${cfg.monitoring.alertEmail}
            ''}
          fi
          
          # Vérifier la charge système
          LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
          LOAD_INT=$(echo "$LOAD * 100" | bc | cut -d. -f1)
          if [ "$LOAD_INT" -gt 200 ]; then
            echo "ALERTE: Charge système élevée sur $HOSTNAME: $LOAD" | logger -t system-monitor
          fi
          
          # Vérifier la mémoire
          MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
          if [ "$MEM_USAGE" -gt 90 ]; then
            echo "ALERTE: Mémoire faible sur $HOSTNAME: $MEM_USAGE%" | logger -t system-monitor
          fi
          
          # Vérifier les services critiques
          for service in sshd k3s; do
            if ! systemctl is-active --quiet $service; then
              echo "ALERTE: Service $service arrêté sur $HOSTNAME" | logger -t system-monitor
              ${optionalString (cfg.monitoring.alertEmail != null) ''
                echo "ALERTE: Service $service arrêté sur $HOSTNAME" | \
                  mail -s "Alerte infra-home: Service arrêté" ${cfg.monitoring.alertEmail}
              ''}
            fi
          done
          
          # Log des statistiques normales
          echo "INFO: $HOSTNAME - Disque: $DISK_USAGE%, Charge: $LOAD, Mémoire: $MEM_USAGE%" | logger -t system-monitor
        '';
      };
    };

    # Timer pour le monitoring (toutes les 15 minutes)
    systemd.timers.system-monitor = mkIf cfg.monitoring.enable {
      description = "Timer pour le monitoring système";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";  # Toutes les 15 minutes
        Persistent = true;
      };
    };

    # Configuration des mises à jour automatiques
    system.autoUpgrade = mkIf cfg.autoUpdates.enable {
      enable = true;
      dates = "daily";
      allowReboot = false;  # Pas de redémarrage automatique
      flake = "/etc/nixos";  # Utiliser la configuration locale
      
      # Script personnalisé pour les mises à jour
      operation = "switch";
    };

    # Timer personnalisé pour les mises à jour
    systemd.timers.nixos-upgrade = mkIf cfg.autoUpdates.enable {
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";  # Délai aléatoire pour éviter la surcharge
        Persistent = true;
      };
    };

    # Packages nécessaires pour le monitoring
    environment.systemPackages = with pkgs; mkIf cfg.monitoring.enable [
      bc          # Calculs dans les scripts
      mailutils   # Envoi d'emails (si configuré)
      htop        # Monitoring interactif
      iotop       # Monitoring I/O
      nethogs     # Monitoring réseau par processus
    ];

    # Configuration des logs pour fail2ban
    services.rsyslog = {
      enable = true;
      extraConfig = ''
        # Logs pour fail2ban
        auth,authpriv.*                 /var/log/auth.log
        kern.*                          /var/log/kern.log
        
        # Rotation des logs
        $WorkDirectory /var/spool/rsyslog
        $ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
      '';
    };

    # Rotation des logs
    services.logrotate = {
      enable = true;
      settings = {
        "/var/log/auth.log" = {
          frequency = "weekly";
          rotate = 4;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          postrotate = "systemctl reload rsyslog";
        };
        
        "/var/log/kern.log" = {
          frequency = "weekly";
          rotate = 4;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          postrotate = "systemctl reload rsyslog";
        };
      };
    };

    # Durcissement supplémentaire du noyau
    boot.kernel.sysctl = {
      # Protection contre les attaques réseau
      "net.ipv4.conf.all.log_martians" = 1;
      "net.ipv4.conf.default.log_martians" = 1;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      
      # Protection contre les attaques SYN flood
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.tcp_max_syn_backlog" = 2048;
      "net.ipv4.tcp_synack_retries" = 2;
      "net.ipv4.tcp_syn_retries" = 5;
      
      # Limiter les pings
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
      
      # Protection contre l'IP spoofing
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
    };

    # Configuration des alertes par email (si configuré)
    programs.msmtp = mkIf (cfg.monitoring.enable && cfg.monitoring.alertEmail != null) {
      enable = true;
      setSendmail = true;
      defaults = {
        aliases = "/etc/aliases";
        port = 587;
        tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
        tls = "on";
        auth = "login";
        timeout = "30";
      };
      accounts = {
        default = {
          host = "smtp.gmail.com";  # Adaptez selon votre fournisseur
          passwordeval = "echo 'VOTRE_MOT_DE_PASSE_APP'";  # À configurer
          user = cfg.monitoring.alertEmail;
          from = cfg.monitoring.alertEmail;
        };
      };
    };

    # Alias email pour root
    environment.etc.aliases = mkIf (cfg.monitoring.enable && cfg.monitoring.alertEmail != null) {
      text = ''
        root: ${cfg.monitoring.alertEmail}
        admin: ${cfg.monitoring.alertEmail}
      '';
    };
  };
}