# Sécurité et Monitoring - Guide complet

Ce guide vous explique comment renforcer la sécurité de votre infrastructure infra-home et mettre en place un monitoring efficace.

## 🎯 Objectifs

Après avoir suivi ce guide, vous aurez :
- ✅ **Fail2ban** configuré pour bloquer les attaques par force brute
- ✅ **Monitoring système** automatique avec alertes
- ✅ **Sauvegardes** automatisées des données critiques
- ✅ **Mises à jour de sécurité** automatiques (optionnel)
- ✅ **Durcissement réseau** avancé

---

## 🛡️ Activation de la sécurité renforcée

### Étape 1 : Activer le module de sécurité

Éditez la configuration de vos hôtes (par exemple `hosts/rpi4-1/configuration.nix`) :

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardening.nix
    ../../modules/topology.nix
    ../../modules/security-enhanced.nix  # Nouveau module
  ];

  # Activer la sécurité renforcée
  security.enhanced = {
    enable = true;
    
    # Configuration fail2ban
    fail2ban = {
      enable = true;
      banTime = "2h";        # Bannir pendant 2 heures
      maxRetry = 3;          # 3 tentatives maximum
    };
    
    # Configuration monitoring
    monitoring = {
      enable = true;
      alertEmail = "admin@votre-domaine.com";  # Votre email pour les alertes
    };
    
    # Mises à jour automatiques (optionnel)
    autoUpdates = {
      enable = false;        # Désactivé par défaut pour la sécurité
      schedule = "03:00";    # 3h du matin si activé
    };
  };
  
  # ... reste de la configuration
}
```

### Étape 2 : Déployer la configuration

```bash
# Valider la configuration
nix flake check

# Déployer sur tous les hôtes
./scripts/deploy-all.sh --ssh

# Ou déployer sur un hôte spécifique
./scripts/deploy-rpi.sh --ssh rpi4-1
```

### Étape 3 : Vérifier l'activation

```bash
# Vérifier que fail2ban fonctionne
ssh admin@rpi4-1 "sudo systemctl status fail2ban"

# Voir les jails actives
ssh admin@rpi4-1 "sudo fail2ban-client status"

# Vérifier le monitoring
ssh admin@rpi4-1 "sudo systemctl status system-monitor.timer"
```

---

## 🚨 Configuration des alertes email

### Prérequis : Configurer l'envoi d'emails

Pour recevoir des alertes par email, vous devez configurer l'envoi d'emails depuis vos Pi.

#### Option 1 : Gmail (recommandée)

1. **Créer un mot de passe d'application Gmail** :
   - Allez dans votre compte Google → Sécurité
   - Activez la validation en 2 étapes
   - Générez un "Mot de passe d'application"

2. **Configurer le secret SOPS** :

```bash
# Éditer le fichier de secrets
sops secrets/email.yaml

# Ajouter votre configuration email
email:
  smtp_password: "votre_mot_de_passe_app_gmail"
  smtp_user: "votre.email@gmail.com"
```

3. **Modifier la configuration NixOS** :

```nix
# Dans votre configuration d'hôte
sops.secrets.email-password = {
  sopsFile = ../../secrets/email.yaml;
  key = "email/smtp_password";
};

programs.msmtp = {
  enable = true;
  setSendmail = true;
  accounts.default = {
    host = "smtp.gmail.com";
    port = 587;
    tls = "on";
    auth = "login";
    user = "votre.email@gmail.com";
    passwordeval = "cat ${config.sops.secrets.email-password.path}";
    from = "votre.email@gmail.com";
  };
};
```

#### Option 2 : Serveur SMTP local (avancé)

Si vous préférez un serveur SMTP local :

```nix
services.postfix = {
  enable = true;
  setSendmail = true;
  relayDomains = [ "hash:/etc/postfix/relay_domains" ];
  config = {
    smtp_tls_security_level = "may";
    smtp_tls_note_starttls_offer = "yes";
  };
};
```

### Test des alertes

```bash
# Tester l'envoi d'email
echo "Test d'alerte infra-home" | mail -s "Test" admin@votre-domaine.com

# Simuler une alerte de disque plein (pour test)
ssh admin@rpi4-1 "sudo systemctl start system-monitor.service"
```

---

## 📊 Monitoring avancé avec Prometheus (optionnel)

Pour un monitoring plus poussé, vous pouvez déployer Prometheus + Grafana sur votre cluster.

### Étape 1 : Créer le manifeste Prometheus

Créez `clusters/base/monitoring/prometheus.yaml` :

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring

---
# ConfigMap pour la configuration Prometheus
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "alert_rules.yml"
    
    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093
    
    scrape_configs:
      # Prometheus lui-même
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      # Node exporters sur les Pi
      - job_name: 'node-exporter'
        static_configs:
          - targets: 
            - '10.10.0.10:9100'  # rpi4-1
            - '10.10.0.11:9100'  # rpi4-2
            - '10.10.0.12:9100'  # rpi3a-ctl
      
      # Kubernetes metrics
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - source_labels: [__address__]
            regex: '(.*):10250'
            target_label: __address__
            replacement: '${1}:9100'

  alert_rules.yml: |
    groups:
      - name: infra-home-alerts
        rules:
          # Alerte si un nœud est down
          - alert: NodeDown
            expr: up{job="node-exporter"} == 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "Nœud {{ $labels.instance }} est inaccessible"
              description: "Le nœud {{ $labels.instance }} ne répond plus depuis plus d'1 minute."
          
          # Alerte disque plein
          - alert: DiskSpaceLow
            expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 15
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Espace disque faible sur {{ $labels.instance }}"
              description: "Il reste moins de 15% d'espace libre sur {{ $labels.device }}."
          
          # Alerte charge CPU élevée
          - alert: HighCPULoad
            expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Charge CPU élevée sur {{ $labels.instance }}"
              description: "La charge CPU est supérieure à 80% depuis plus de 10 minutes."

---
# Déploiement Prometheus
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--storage.tsdb.retention.time=30d'
          - '--web.enable-lifecycle'
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        emptyDir: {}

---
# Service Prometheus
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP

---
# Ingress pour accéder à Prometheus
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: "traefik"
spec:
  rules:
  - host: prometheus.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus
            port:
              number: 9090
```

### Étape 2 : Déployer Node Exporter sur les Pi

Ajoutez dans vos configurations d'hôtes :

```nix
# Dans hosts/*/configuration.nix
services.prometheus.exporters.node = {
  enable = true;
  port = 9100;
  enabledCollectors = [
    "systemd"
    "textfile"
    "filesystem"
    "loadavg"
    "meminfo"
    "netdev"
    "stat"
  ];
  # Ouvrir le port dans le pare-feu
  openFirewall = true;
};
```

### Étape 3 : Ajouter Grafana

Créez `clusters/base/monitoring/grafana.yaml` :

```yaml
---
# Déploiement Grafana
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin123"  # Changez ce mot de passe !
        volumeMounts:
        - name: storage
          mountPath: /var/lib/grafana
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: storage
        emptyDir: {}

---
# Service Grafana
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000

---
# Ingress Grafana
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: "traefik"
spec:
  rules:
  - host: grafana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
```

### Étape 4 : Déployer le monitoring

```bash
# Ajouter les manifestes à Kustomize
echo "  - monitoring/prometheus.yaml" >> clusters/base/kustomization.yaml
echo "  - monitoring/grafana.yaml" >> clusters/base/kustomization.yaml

# Déployer
make render ENV=review
make deploy ENV=review

# Vérifier le déploiement
kubectl get pods -n monitoring
```

### Étape 5 : Accéder aux interfaces

```bash
# Ajouter les entrées DNS locales
echo "10.10.0.10 prometheus.local" >> /etc/hosts
echo "10.10.0.10 grafana.local" >> /etc/hosts

# Accéder aux interfaces
# Prometheus: http://prometheus.local
# Grafana: http://grafana.local (admin/admin123)
```

---

## 💾 Stratégie de sauvegarde

### Sauvegarde automatique des secrets OpenBao

Créez `scripts/backup-openbao.sh` :

```bash
#!/bin/bash
# Script de sauvegarde automatique d'OpenBao

set -e

BACKUP_DIR="/opt/backups/openbao"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/openbao_backup_$DATE.tar.gz.age"

# Créer le répertoire de sauvegarde
mkdir -p "$BACKUP_DIR"

echo "🔐 Démarrage de la sauvegarde OpenBao..."

# Exporter les données OpenBao
kubectl exec -n openbao deployment/openbao -- \
  vault operator raft snapshot save /tmp/vault-snapshot.snap

# Récupérer le snapshot
kubectl cp openbao/$(kubectl get pods -n openbao -l app=openbao -o jsonpath='{.items[0].metadata.name}'):/tmp/vault-snapshot.snap \
  /tmp/vault-snapshot.snap

# Créer l'archive chiffrée
tar -czf - /tmp/vault-snapshot.snap | \
  age -r $(cat ~/.config/age/key.txt.pub) > "$BACKUP_FILE"

# Nettoyer
rm -f /tmp/vault-snapshot.snap

# Garder seulement les 7 dernières sauvegardes
find "$BACKUP_DIR" -name "openbao_backup_*.tar.gz.age" -mtime +7 -delete

echo "✅ Sauvegarde terminée : $BACKUP_FILE"

# Vérifier la taille du fichier
SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "📊 Taille de la sauvegarde : $SIZE"

# Envoyer une notification (si configuré)
if command -v mail >/dev/null 2>&1; then
    echo "Sauvegarde OpenBao terminée avec succès. Taille: $SIZE" | \
        mail -s "Sauvegarde infra-home - $(date)" admin@votre-domaine.com
fi
```

### Sauvegarde des configurations NixOS

Créez `scripts/backup-configs.sh` :

```bash
#!/bin/bash
# Script de sauvegarde des configurations

set -e

BACKUP_DIR="/opt/backups/configs"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/configs_backup_$DATE.tar.gz.age"

mkdir -p "$BACKUP_DIR"

echo "📁 Sauvegarde des configurations..."

# Créer l'archive des configurations importantes
tar -czf - \
  /etc/nixos/ \
  /etc/ssh/ssh_host_* \
  /etc/machine-id \
  /var/lib/kubernetes/ \
  /var/lib/k3s/ \
  2>/dev/null | \
  age -r $(cat ~/.config/age/key.txt.pub) > "$BACKUP_FILE"

# Garder 30 jours de sauvegardes
find "$BACKUP_DIR" -name "configs_backup_*.tar.gz.age" -mtime +30 -delete

echo "✅ Sauvegarde des configurations terminée : $BACKUP_FILE"
```

### Automatisation des sauvegardes

Ajoutez dans vos configurations d'hôtes :

```nix
# Tâches cron pour les sauvegardes
services.cron = {
  enable = true;
  systemCronJobs = [
    # Sauvegarde OpenBao tous les jours à 2h
    "0 2 * * * root /opt/scripts/backup-openbao.sh"
    
    # Sauvegarde des configs toutes les semaines
    "0 3 * * 0 root /opt/scripts/backup-configs.sh"
    
    # Nettoyage des logs anciens
    "0 4 * * * root find /var/log -name '*.log' -mtime +30 -delete"
  ];
};

# Copier les scripts de sauvegarde
environment.etc."scripts/backup-openbao.sh" = {
  source = ../../scripts/backup-openbao.sh;
  mode = "0755";
};

environment.etc."scripts/backup-configs.sh" = {
  source = ../../scripts/backup-configs.sh;
  mode = "0755";
};
```

---

## 🔍 Surveillance des logs

### Configuration centralisée des logs

Pour centraliser les logs de tous vos Pi :

```nix
# Sur le Pi principal (rpi4-1)
services.rsyslog = {
  enable = true;
  extraConfig = ''
    # Serveur de logs centralisé
    $ModLoad imudp
    $UDPServerRun 514
    $UDPServerAddress 10.10.0.10
    
    # Template pour les logs distants
    $template RemoteLogs,"/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log"
    *.* ?RemoteLogs
    & stop
  '';
};

# Sur les autres Pi
services.rsyslog = {
  enable = true;
  extraConfig = ''
    # Envoyer les logs vers le serveur central
    *.* @10.10.0.10:514
  '';
};
```

### Analyse des logs avec fail2ban

Créez des filtres personnalisés pour détecter les activités suspectes :

```bash
# Créer un filtre pour les tentatives d'accès k3s non autorisées
cat > /etc/fail2ban/filter.d/k3s-auth.conf << 'EOF'
[Definition]
failregex = .*k3s.*authentication failed.*from <HOST>
            .*k3s.*unauthorized.*<HOST>
ignoreregex =
EOF

# Ajouter le jail correspondant
cat >> /etc/fail2ban/jail.local << 'EOF'
[k3s-auth]
enabled = true
filter = k3s-auth
logpath = /var/log/k3s.log
maxretry = 3
bantime = 1h
EOF
```

---

## 📋 Checklist de sécurité

### Vérifications quotidiennes automatiques

Créez `scripts/security-check.sh` :

```bash
#!/bin/bash
# Script de vérification de sécurité quotidienne

echo "🔍 Vérification de sécurité infra-home - $(date)"

# Vérifier les services critiques
SERVICES=("sshd" "k3s" "fail2ban" "rsyslog")
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "✅ $service: OK"
    else
        echo "❌ $service: FAILED"
        echo "ALERTE: Service $service arrêté" | logger -t security-check
    fi
done

# Vérifier les connexions SSH actives
SSH_CONNECTIONS=$(who | wc -l)
if [ "$SSH_CONNECTIONS" -gt 2 ]; then
    echo "⚠️  Connexions SSH multiples détectées: $SSH_CONNECTIONS"
    who | logger -t security-check
fi

# Vérifier les tentatives de connexion échouées
FAILED_SSH=$(grep "Failed password" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l)
if [ "$FAILED_SSH" -gt 10 ]; then
    echo "⚠️  Nombreuses tentatives SSH échouées: $FAILED_SSH"
fi

# Vérifier l'état de fail2ban
BANNED_IPS=$(fail2ban-client status sshd | grep "Banned IP list" | wc -w)
if [ "$BANNED_IPS" -gt 3 ]; then
    echo "🚫 IPs bannies par fail2ban: $((BANNED_IPS - 4))"
    fail2ban-client status sshd | logger -t security-check
fi

# Vérifier les mises à jour de sécurité disponibles
UPDATES=$(nix-channel --update && nix-env -u --dry-run 2>/dev/null | grep "would be" | wc -l)
if [ "$UPDATES" -gt 0 ]; then
    echo "📦 Mises à jour disponibles: $UPDATES"
fi

echo "✅ Vérification de sécurité terminée"
```

### Checklist manuelle hebdomadaire

- [ ] **Vérifier les logs de fail2ban** : `sudo fail2ban-client status`
- [ ] **Contrôler l'espace disque** : `df -h`
- [ ] **Vérifier les sauvegardes** : `ls -la /opt/backups/`
- [ ] **Tester la restauration** d'une sauvegarde OpenBao
- [ ] **Vérifier les certificats SSL** : dates d'expiration
- [ ] **Contrôler les utilisateurs** : `cat /etc/passwd`
- [ ] **Vérifier les clés SSH** autorisées
- [ ] **Tester les alertes email**
- [ ] **Vérifier les mises à jour** : `nix flake update`
- [ ] **Contrôler les performances** : `htop`, `iotop`

---

## 🚨 Procédures d'incident

### En cas de compromission suspectée

1. **Isoler immédiatement** :
```bash
# Couper l'accès réseau
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP

# Garder seulement SSH local
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT
```

2. **Analyser les logs** :
```bash
# Connexions récentes
last -n 20
who

# Tentatives de connexion
grep "Failed password" /var/log/auth.log | tail -20
grep "Accepted password" /var/log/auth.log | tail -10

# Processus suspects
ps aux | grep -v "\[.*\]" | sort -k3 -nr | head -10
```

3. **Vérifier l'intégrité** :
```bash
# Fichiers modifiés récemment
find /etc /usr/bin /usr/sbin -type f -mtime -1

# Connexions réseau actives
netstat -tulpn | grep LISTEN
```

4. **Restaurer depuis une sauvegarde** si nécessaire

### En cas de panne de service

1. **Diagnostiquer** :
```bash
# État des services
systemctl status k3s fail2ban sshd

# Logs récents
journalctl -u k3s -f --since "10 minutes ago"
```

2. **Redémarrer les services** :
```bash
sudo systemctl restart k3s
sudo systemctl restart fail2ban
```

3. **Vérifier la connectivité** :
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

---

> 💡 **Conseil** : Testez régulièrement vos procédures de sauvegarde et de restauration. Une sauvegarde non testée n'est pas une vraie sauvegarde !

> ⚠️ **Important** : Gardez toujours un accès de secours (console physique, clé USB de récupération) en cas de problème avec SSH ou le réseau.