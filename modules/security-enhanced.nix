# Module de sécurité renforcée pour infra-home
# Fournit fail2ban, monitoring système, durcissement réseau et alertes
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.roles.security-enhanced;
in
{
  options.roles.security-enhanced = {
    enable = mkEnableOption "sécurité renforcée avec fail2ban et monitoring";
    
    fail2ban = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Activer fail2ban pour la protection contre les intrusions";
      };
      
      banTime = mkOption {
        type = types.str;
        default = "1h";
        description = "Durée de bannissement par défaut";
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
        description = "Activer le monitoring système avec alertes";
      };
      
      alertEmail = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Email pour recevoir les alertes (optionnel)";
        example = "admin@example.com";
      };
      
      checkInterval = mkOption {
        type = types.str;
        default = "5min";
        description = "Intervalle de vérification du monitoring";
      };
    };
    
    autoUpdates = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Activer les mises à jour automatiques (recommandé: false)";
      };
      
      schedule = mkOption {
        type = types.str;
        default = "weekly";
        description = "Fréquence des mises à jour automatiques";
      };
    };
  };

  config = mkIf cfg.enable {
    
    # Configuration des services
    services = mkMerge [
      # Configuration fail2ban
      (mkIf cfg.fail2ban.enable {
        fail2ban = {
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
      })
      
      # Configuration rsyslog pour les logs fail2ban
      (mkIf cfg.fail2ban.enable {
        rsyslog = {
          enable = true;
          extraConfig = ''
            # Logs pour fail2ban
            :msg,contains,"kernel:" /var/log/kern.log
            & stop
            
            # Logs d'authentification
            auth,authpriv.* /var/log/auth.log
            & stop
          '';
        };
      })
      
      # Configuration logrotate
      (mkIf cfg.monitoring.enable {
        logrotate = {
          enable = true;
          settings = {
            "/var/log/auth.log" = {
              frequency = "daily";
              rotate = 7;
              compress = true;
              delaycompress = true;
              missingok = true;
              notifempty = true;
              create = "640 root adm";
            };
            "/var/log/kern.log" = {
              frequency = "daily";
              rotate = 7;
              compress = true;
              delaycompress = true;
              missingok = true;
              notifempty = true;
            };
          };
        };
      })
    ];

    # Configuration de l'environnement
    environment = mkMerge [
      # Filtres fail2ban personnalisés
      (mkIf cfg.fail2ban.enable {
        etc."fail2ban/filter.d/port-scan.conf".text = ''
          [Definition]
          failregex = .*kernel:.*IN=.*OUT=.*SRC=<HOST>.*DPT=(22|23|53|80|110|143|443|993|995).*
          ignoreregex =
        '';
      })
      
      # Packages système pour monitoring
      (mkIf cfg.monitoring.enable {
        systemPackages = with pkgs; [
          bc          # Calculs dans les scripts
          curl        # Tests de connectivité
          jq          # Parsing JSON
          htop        # Monitoring interactif
          iotop       # Monitoring I/O
          nethogs     # Monitoring réseau par processus
        ];
      })
      
      # Configuration des alias email
      (mkIf (cfg.monitoring.enable && cfg.monitoring.alertEmail != null) {
        etc.aliases = {
          text = ''
            root: ${cfg.monitoring.alertEmail}
            postmaster: ${cfg.monitoring.alertEmail}
            abuse: ${cfg.monitoring.alertEmail}
          '';
        };
      })
    ];

    # Configuration systemd
    systemd = mkMerge [
      # Service de monitoring système
      (mkIf cfg.monitoring.enable {
        services.system-monitor = {
          description = "Monitoring système avec alertes";
          wantedBy = [ "multi-user.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = pkgs.writeShellScript "system-monitor" ''
              #!/bin/bash
              set -euo pipefail
              
              # Configuration
              ALERT_EMAIL="${optionalString (cfg.monitoring.alertEmail != null) cfg.monitoring.alertEmail}"
              HOSTNAME=$(hostname)
              TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
              
              # Fonction d'alerte
              send_alert() {
                local subject="$1"
                local message="$2"
                
                if [[ -n "$ALERT_EMAIL" ]]; then
                  echo "$message" | mail -s "[$HOSTNAME] $subject" "$ALERT_EMAIL" || true
                fi
                
                # Log local
                logger -t system-monitor "$subject: $message"
              }
              
              # Vérification de l'espace disque
              check_disk_space() {
                local usage
                usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
                
                if [[ $usage -gt 90 ]]; then
                  send_alert "CRITIQUE: Espace disque faible" \
                    "L'espace disque est à $usage% sur $HOSTNAME à $TIMESTAMP"
                elif [[ $usage -gt 80 ]]; then
                  send_alert "ATTENTION: Espace disque" \
                    "L'espace disque est à $usage% sur $HOSTNAME à $TIMESTAMP"
                fi
              }
              
              # Vérification de la charge système
              check_load() {
                local load_1min
                load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
                local cpu_count
                cpu_count=$(nproc)
                local load_threshold
                load_threshold=$(echo "$cpu_count * 2" | bc)
                
                if (( $(echo "$load_1min > $load_threshold" | bc -l) )); then
                  send_alert "ATTENTION: Charge système élevée" \
                    "Charge 1min: $load_1min (seuil: $load_threshold) sur $HOSTNAME à $TIMESTAMP"
                fi
              }
              
              # Vérification de la mémoire
              check_memory() {
                local mem_usage
                mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
                
                if [[ $mem_usage -gt 90 ]]; then
                  send_alert "CRITIQUE: Mémoire faible" \
                    "Utilisation mémoire: $mem_usage% sur $HOSTNAME à $TIMESTAMP"
                elif [[ $mem_usage -gt 80 ]]; then
                  send_alert "ATTENTION: Mémoire élevée" \
                    "Utilisation mémoire: $mem_usage% sur $HOSTNAME à $TIMESTAMP"
                fi
              }
              
              # Vérification des services critiques
              check_services() {
                local services=("sshd" "systemd-networkd")
                
                for service in "''${services[@]}"; do
                  if ! systemctl is-active --quiet "$service"; then
                    send_alert "CRITIQUE: Service arrêté" \
                      "Le service $service est arrêté sur $HOSTNAME à $TIMESTAMP"
                  fi
                done
              }
              
              # Exécution des vérifications
              check_disk_space
              check_load
              check_memory
              check_services
              
              echo "Monitoring terminé à $TIMESTAMP"
            '';
          };
        };
      })
      
      # Timer pour le monitoring
      (mkIf cfg.monitoring.enable {
        timers.system-monitor = {
          description = "Timer pour le monitoring système";
          wantedBy = [ "timers.target" ];
          
          timerConfig = {
            OnCalendar = cfg.monitoring.checkInterval;
            Persistent = true;
            RandomizedDelaySec = "1min";
          };
        };
      })
      
      # Timer pour les mises à jour automatiques (optionnel)
      (mkIf cfg.autoUpdates.enable {
        timers.nixos-upgrade = {
          timerConfig = {
            OnCalendar = cfg.autoUpdates.schedule;
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };
      })
    ];

    # Durcissement réseau avec sysctl
    boot.kernel.sysctl = mkIf cfg.enable {
      # Protection contre les attaques réseau
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      
      # Protection contre le spoofing
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      
      # Désactiver le forwarding IP par défaut (sera activé par le module router si nécessaire)
      "net.ipv4.ip_forward" = 0;
      "net.ipv6.conf.all.forwarding" = 0;
      
      # Protection contre les attaques SYN flood
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.tcp_max_syn_backlog" = 2048;
      "net.ipv4.tcp_synack_retries" = 3;
      
      # Ignorer les pings ICMP
      "net.ipv4.icmp_echo_ignore_all" = 1;
      
      # Logs des paquets suspects
      "net.ipv4.conf.all.log_martians" = 1;
      "net.ipv4.conf.default.log_martians" = 1;
    };

    # Configuration du pare-feu avec nftables
    networking.nftables = mkIf cfg.enable {
      enable = true;
      
      # Règles de base pour la sécurité
      ruleset = ''
        table inet filter {
          # Chaîne d'entrée
          chain input {
            type filter hook input priority filter; policy drop;
            
            # Autoriser le loopback
            iif "lo" accept
            
            # Autoriser les connexions établies et liées
            ct state established,related accept
            
            # Autoriser SSH (port 22)
            tcp dport 22 ct state new accept
            
            # Autoriser ICMP (ping) de manière limitée
            icmp type echo-request limit rate 1/second accept
            
            # Logs des paquets rejetés (pour fail2ban)
            log prefix "DROPPED: " level info drop
          }
          
          # Chaîne de sortie (permissive par défaut)
          chain output {
            type filter hook output priority filter; policy accept;
          }
          
          # Chaîne de forwarding (sera configurée par le module router si nécessaire)
          chain forward {
            type filter hook forward priority filter; policy drop;
          }
        }
      '';
    };
  };
}