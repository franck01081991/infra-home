# Exemples d'extensibilité - Guide pratique

Ce guide vous montre comment étendre votre infrastructure infra-home avec des exemples concrets et prêts à l'emploi. Chaque exemple est accompagné d'explications détaillées pour les techniciens débutants.

## 🎯 Objectifs

Après avoir suivi ces exemples, vous saurez :
- ✅ Ajouter un nouvel hôte (PC x86, nouveau Pi, etc.)
- ✅ Déployer une application web sur votre cluster
- ✅ Créer un nouveau VLAN pour segmenter votre réseau
- ✅ Exposer un service vers Internet de manière sécurisée
- ✅ Ajouter des règles de pare-feu personnalisées

---

## 📱 Exemple 1 : Ajouter un nouvel hôte (PC x86)

Supposons que vous voulez ajouter un PC de bureau comme worker Kubernetes.

### Étape 1 : Déclarer l'hôte dans la topologie

Éditez le fichier `infra/topology.nix` :

```nix
# Dans la section hosts = {
hosts = {
  # ... hôtes existants ...
  
  # Nouveau PC de bureau
  "pc-desktop" = {
    # Ce n'est pas un routeur
    router = false;
    
    # Configuration k3s : worker uniquement
    k3s = {
      role = "worker";           # Rôle worker (pas master)
      initCluster = false;       # Ne pas initialiser le cluster
      serverAddr = "https://10.10.0.10:6443";  # Adresse du master (rpi4-1)
    };
    
    # Adresses IP par VLAN
    addresses = {
      infra = "10.10.0.20/24";   # IP dans le VLAN infrastructure
    };
    
    # Architecture (important pour les déploiements)
    arch = "x86_64-linux";
  };
};
```

**💡 Explication :**
- `router = false` : Ce PC ne fait pas de routage
- `role = "worker"` : Il ne sera que worker Kubernetes (pas master)
- `initCluster = false` : Il rejoint un cluster existant
- `serverAddr` : Adresse du master k3s (rpi4-1)
- `arch = "x86_64-linux"` : Architecture x86 (différente des Pi ARM)

### Étape 2 : Créer la configuration de l'hôte

```bash
# Créer le répertoire pour le nouvel hôte
mkdir -p hosts/pc-desktop

# Copier un template de configuration
cp hosts/rpi4-2/configuration.nix hosts/pc-desktop/
```

Éditez `hosts/pc-desktop/configuration.nix` :

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardening.nix      # Sécurité de base
    ../../modules/topology.nix       # Import de la topologie
  ];

  # Nom d'hôte (doit correspondre à la topologie)
  networking.hostName = "pc-desktop";

  # Activer les rôles k3s (worker uniquement)
  roles.k3s.enable = true;

  # Configuration spécifique x86 (si nécessaire)
  # Par exemple, pilotes graphiques, etc.
  
  # Version NixOS
  system.stateVersion = "23.11";
}
```

### Étape 3 : Générer la configuration matérielle

Sur le PC de bureau, après avoir installé NixOS :

```bash
# Générer la configuration matérielle
sudo nixos-generate-config --root /mnt

# Copier le fichier généré dans votre projet
scp root@PC_IP:/mnt/etc/nixos/hardware-configuration.nix hosts/pc-desktop/
```

### Étape 4 : Ajouter l'hôte au flake

Éditez `flake.nix` pour ajouter la nouvelle configuration :

```nix
# Dans nixosConfigurations
nixosConfigurations = {
  # ... configurations existantes ...
  
  pc-desktop = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";  # Architecture x86
    modules = [
      ./hosts/pc-desktop/configuration.nix
    ];
  };
};
```

### Étape 5 : Déployer

```bash
# Valider la configuration
nix flake check

# Déployer sur le PC
./scripts/deploy-rpi.sh --ssh pc-desktop
```

---

## 🌐 Exemple 2 : Déployer une application web

Déployons un site web simple (nginx) accessible depuis le VLAN PERSO.

### Étape 1 : Créer le manifeste de l'application

Créez `clusters/base/apps/mon-site-web.yaml` :

```yaml
---
# Namespace pour notre application
apiVersion: v1
kind: Namespace
metadata:
  name: mon-site-web
  labels:
    name: mon-site-web

---
# Déploiement nginx
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: mon-site-web
spec:
  replicas: 2  # 2 instances pour la redondance
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
        # Configuration personnalisée
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config

---
# Configuration nginx
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: mon-site-web
data:
  default.conf: |
    server {
        listen 80;
        server_name _;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        # Page de santé
        location /health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }
    }

---
# Service pour exposer l'application
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: mon-site-web
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP

---
# Ingress pour l'accès externe
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: mon-site-web
  annotations:
    # Utiliser Traefik comme ingress controller
    kubernetes.io/ingress.class: "traefik"
    # Redirection HTTPS automatique
    traefik.ingress.kubernetes.io/redirect-entry-point: https
spec:
  rules:
  - host: mon-site.local  # Nom de domaine local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
```

**💡 Explication :**
- **Namespace** : Isole notre application
- **Deployment** : Définit 2 répliques nginx pour la redondance
- **ConfigMap** : Configuration nginx personnalisée
- **Service** : Expose l'application dans le cluster
- **Ingress** : Permet l'accès depuis l'extérieur via Traefik

### Étape 2 : Ajouter l'application à Kustomize

Éditez `clusters/base/kustomization.yaml` :

```yaml
resources:
  # ... ressources existantes ...
  - apps/mon-site-web.yaml  # Ajouter notre application
```

### Étape 3 : Déployer via GitOps

```bash
# Générer les manifestes
make render ENV=review

# Vérifier que tout est correct
kubectl apply --dry-run=client -f clusters/review/

# Déployer en review
make deploy ENV=review

# Vérifier le déploiement
kubectl get pods -n mon-site-web
kubectl get ingress -n mon-site-web
```

### Étape 4 : Tester l'application

```bash
# Depuis un appareil sur le VLAN PERSO
curl http://mon-site.local

# Ou ajouter l'entrée DNS dans /etc/hosts
echo "10.10.0.10 mon-site.local" >> /etc/hosts
```

---

## 🔒 Exemple 3 : Créer un nouveau VLAN (CAMERAS)

Ajoutons un VLAN dédié aux caméras de sécurité.

### Étape 1 : Définir le nouveau VLAN

Éditez `infra/topology.nix` :

```nix
vlans = {
  # ... VLANs existants ...
  
  # Nouveau VLAN pour les caméras
  cameras = {
    id = 50;                    # ID VLAN unique
    subnet = "10.50.0.0/24";    # Sous-réseau dédié
    gateway = "10.50.0.1";      # Passerelle (le routeur)
    
    # Plage DHCP pour les caméras
    dhcp = {
      enable = true;
      range = "10.50.0.100,10.50.0.200";  # IPs automatiques
      leaseTime = "24h";        # Bail DHCP long
    };
    
    # Ports autorisés en entrée
    ingressTcpPorts = [ 
      22    # SSH pour l'administration
      80    # Interface web des caméras
      554   # RTSP pour les flux vidéo
    ];
    
    # Règles de transfert vers d'autres VLANs
    forwardRules = [
      # Autoriser l'accès depuis INFRA vers CAMERAS
      {
        from = "infra";
        to = "cameras";
        ports = [ 80 554 ];     # Web et RTSP uniquement
        protocol = "tcp";
      }
      # Interdire tout autre accès
    ];
  };
};
```

**💡 Explication :**
- `id = 50` : Identifiant VLAN unique (différent des autres)
- `subnet` : Plage d'adresses IP dédiée aux caméras
- `dhcp` : Configuration automatique des caméras
- `ingressTcpPorts` : Ports accessibles depuis l'extérieur du VLAN
- `forwardRules` : Règles de communication inter-VLAN

### Étape 2 : Configurer le Wi-Fi pour les caméras

Ajoutez un SSID dédié dans la configuration du routeur. Éditez la configuration de `rpi4-1` :

```nix
# Dans hosts/rpi4-1/configuration.nix
networking.wireless.networks = {
  # ... réseaux existants ...
  
  # SSID pour les caméras
  "CAMERAS_SECURE" = {
    psk = "mot_de_passe_cameras_tres_long_et_securise";
    # Forcer ce SSID sur le VLAN cameras
    extraConfig = ''
      bridge=br-cameras
    '';
  };
};
```

### Étape 3 : Déployer la configuration

```bash
# Valider la nouvelle topologie
nix flake check

# Déployer sur le routeur
./scripts/deploy-rpi.sh --ssh rpi4-1

# Vérifier que le VLAN est créé
ssh admin@rpi4-1 "ip link show | grep cameras"
ssh admin@rpi4-1 "ip addr show br-cameras"
```

### Étape 4 : Tester la connectivité

```bash
# Connecter une caméra au SSID CAMERAS_SECURE
# Elle devrait obtenir une IP dans 10.50.0.100-200

# Tester depuis le VLAN INFRA
ping 10.50.0.100  # IP de la caméra

# Tester l'accès web
curl http://10.50.0.100  # Interface web de la caméra
```

---

## 🌍 Exemple 4 : Exposer un service vers Internet

Exposons notre site web vers Internet de manière sécurisée.

### Étape 1 : Configurer le port forwarding

Éditez la configuration du routeur dans `modules/roles/router.nix` :

```nix
# Ajouter des règles NAT pour l'exposition Internet
networking.nat = {
  enable = true;
  externalInterface = "wlan0";  # Interface 4G/WAN
  internalIPs = [ "10.10.0.0/16" ];
  
  # Règles de redirection de port
  forwardPorts = [
    {
      sourcePort = 80;          # Port externe (Internet)
      destination = "10.10.0.10:80";  # IP:port interne
      proto = "tcp";
    }
    {
      sourcePort = 443;         # HTTPS
      destination = "10.10.0.10:443";
      proto = "tcp";
    }
  ];
};

# Règles de pare-feu pour autoriser l'entrée
networking.firewall = {
  allowedTCPPorts = [ 80 443 ];
  
  # Règles avancées avec nftables
  extraCommands = ''
    # Limiter les connexions pour éviter les attaques
    iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
  '';
};
```

**💡 Explication :**
- `forwardPorts` : Redirige le trafic Internet vers le cluster
- `allowedTCPPorts` : Ouvre les ports sur le pare-feu
- `extraCommands` : Limite le taux de connexions (protection DDoS basique)

### Étape 2 : Configurer HTTPS avec Let's Encrypt

Modifiez l'ingress de votre application :

```yaml
# Dans clusters/base/apps/mon-site-web.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: mon-site-web
  annotations:
    kubernetes.io/ingress.class: "traefik"
    # Certificat automatique Let's Encrypt
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Redirection HTTPS forcée
    traefik.ingress.kubernetes.io/redirect-entry-point: https
spec:
  tls:
  - hosts:
    - votre-domaine.com
    secretName: mon-site-tls
  rules:
  - host: votre-domaine.com  # Votre vrai domaine
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
```

### Étape 3 : Configurer le DNS

Chez votre registraire de domaine :

```
Type: A
Nom: votre-domaine.com
Valeur: VOTRE_IP_PUBLIQUE_4G
TTL: 300
```

### Étape 4 : Déployer et tester

```bash
# Déployer la nouvelle configuration
./scripts/deploy-rpi.sh --ssh rpi4-1
make deploy ENV=prod

# Tester depuis Internet
curl https://votre-domaine.com
```

---

## 🛡️ Exemple 5 : Règles de pare-feu avancées

Créons des règles personnalisées pour sécuriser notre infrastructure.

### Étape 1 : Règles inter-VLAN personnalisées

Éditez `infra/topology.nix` pour ajouter des règles spécifiques :

```nix
# Dans la configuration d'un VLAN
perso = {
  # ... configuration existante ...
  
  forwardRules = [
    # Autoriser l'accès web vers INFRA (pour les services)
    {
      from = "perso";
      to = "infra";
      ports = [ 80 443 ];
      protocol = "tcp";
      # Condition supplémentaire : seulement en journée
      extraConditions = "hour 8-18";
    }
    
    # Bloquer complètement l'accès vers IOT
    {
      from = "perso";
      to = "iot";
      action = "drop";  # Bloquer au lieu d'autoriser
    }
    
    # Autoriser DNS uniquement
    {
      from = "perso";
      to = "infra";
      ports = [ 53 ];
      protocol = "udp";
      # Toujours autorisé (pas de condition de temps)
    }
  ];
};
```

### Étape 2 : Protection contre les attaques

Ajoutez des règles de protection dans `modules/roles/router.nix` :

```nix
# Protection avancée avec nftables
networking.nftables = {
  enable = true;
  ruleset = ''
    table inet filter {
      # Chaîne pour la protection DDoS
      chain ddos_protection {
        # Limiter les nouvelles connexions TCP
        tcp flags syn limit rate 10/second burst 20 packets accept
        tcp flags syn drop
        
        # Limiter les pings
        icmp type echo-request limit rate 5/second burst 10 packets accept
        icmp type echo-request drop
      }
      
      # Chaîne pour bloquer les IPs suspectes
      chain blacklist {
        # Bloquer les tentatives de brute force SSH
        tcp dport 22 ct state new limit rate 3/minute burst 3 packets accept
        tcp dport 22 ct state new drop
        
        # Bloquer les scans de ports
        tcp flags & (fin|syn|rst|psh|ack|urg) == fin|syn|rst|psh|ack|urg drop
        tcp flags & (fin|syn|rst|psh|ack|urg) == 0 drop
      }
      
      # Appliquer les protections
      chain input {
        type filter hook input priority 0; policy drop;
        
        # Connexions établies et liées
        ct state established,related accept
        
        # Interface de loopback
        iifname "lo" accept
        
        # Appliquer les protections
        jump ddos_protection
        jump blacklist
        
        # Autoriser SSH depuis les VLANs internes uniquement
        ip saddr 10.0.0.0/8 tcp dport 22 accept
        
        # Autoriser les services nécessaires
        tcp dport { 80, 443 } accept
        udp dport { 53, 67, 68 } accept
      }
    }
  '';
};
```

**💡 Explication :**
- `ddos_protection` : Limite les connexions pour éviter les attaques DDoS
- `blacklist` : Bloque les tentatives de brute force et scans de ports
- `ct state` : Utilise le suivi de connexion pour optimiser les performances
- `ip saddr 10.0.0.0/8` : Limite SSH aux réseaux internes uniquement

---

## 🔧 Scripts d'aide

Créons quelques scripts pour automatiser ces tâches courantes.

### Script d'ajout d'hôte

Créez `scripts/add-host.sh` :

```bash
#!/bin/bash
# Script pour ajouter facilement un nouvel hôte

set -e

HOST_NAME="$1"
HOST_ARCH="$2"
HOST_IP="$3"

if [ -z "$HOST_NAME" ] || [ -z "$HOST_ARCH" ] || [ -z "$HOST_IP" ]; then
    echo "Usage: $0 <nom-hote> <architecture> <ip>"
    echo "Exemple: $0 pc-desktop x86_64-linux 10.10.0.20"
    exit 1
fi

echo "🚀 Ajout de l'hôte $HOST_NAME..."

# Créer le répertoire
mkdir -p "hosts/$HOST_NAME"

# Copier le template de configuration
cat > "hosts/$HOST_NAME/configuration.nix" << EOF
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/hardening.nix
    ../../modules/topology.nix
  ];

  networking.hostName = "$HOST_NAME";
  roles.k3s.enable = true;
  system.stateVersion = "23.11";
}
EOF

echo "✅ Configuration créée dans hosts/$HOST_NAME/"
echo "📝 N'oubliez pas de :"
echo "   1. Ajouter l'hôte dans infra/topology.nix"
echo "   2. Ajouter la configuration dans flake.nix"
echo "   3. Copier hardware-configuration.nix depuis la machine"
echo "   4. Déployer avec ./scripts/deploy-rpi.sh --ssh $HOST_NAME"
```

### Script de test de connectivité

Créez `scripts/test-network.sh` :

```bash
#!/bin/bash
# Script pour tester la connectivité réseau

echo "🌐 Test de connectivité réseau infra-home..."

# Tester les hôtes principaux
HOSTS=("rpi4-1:10.10.0.10" "rpi4-2:10.10.0.11" "rpi3a-ctl:10.10.0.12")

for host_info in "${HOSTS[@]}"; do
    host_name="${host_info%:*}"
    host_ip="${host_info#*:}"
    
    echo -n "Testing $host_name ($host_ip)... "
    if ping -c 1 -W 2 "$host_ip" >/dev/null 2>&1; then
        echo "✅ OK"
        
        # Test SSH
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "admin@$host_ip" "echo SSH OK" >/dev/null 2>&1; then
            echo "  SSH: ✅ OK"
        else
            echo "  SSH: ❌ FAILED"
        fi
        
        # Test k3s
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "admin@$host_ip" "sudo systemctl is-active k3s" >/dev/null 2>&1; then
            echo "  k3s: ✅ OK"
        else
            echo "  k3s: ❌ FAILED"
        fi
    else
        echo "❌ UNREACHABLE"
    fi
    echo
done

# Tester les VLANs
echo "🔍 Test des VLANs..."
VLANS=("10.10.0.1:INFRA" "10.20.0.1:PRO" "10.30.0.1:PERSO" "10.40.0.1:IOT")

for vlan_info in "${VLANS[@]}"; do
    vlan_ip="${vlan_info%:*}"
    vlan_name="${vlan_info#*:}"
    
    echo -n "Testing VLAN $vlan_name ($vlan_ip)... "
    if ping -c 1 -W 2 "$vlan_ip" >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ UNREACHABLE"
    fi
done
```

---

## 📚 Ressources supplémentaires

### Documentation utile
- **NixOS Manual** : https://nixos.org/manual/nixos/stable/
- **Kubernetes Docs** : https://kubernetes.io/docs/
- **Traefik Docs** : https://doc.traefik.io/traefik/
- **nftables Guide** : https://wiki.nftables.org/

### Outils de debug
```bash
# Vérifier la configuration Nix
nix flake check --verbose

# Voir les logs système
journalctl -u k3s -f

# Debug réseau
ip addr show
ip route show
nft list ruleset

# Debug Kubernetes
kubectl get nodes -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

---

> 💡 **Conseil** : Commencez par un exemple simple (comme ajouter un hôte) avant de passer aux configurations réseau avancées. Chaque modification doit être testée avant de passer à la suivante !

> ⚠️ **Sécurité** : Toujours tester les règles de pare-feu en local avant de les appliquer sur un système distant. Une mauvaise règle peut vous couper l'accès SSH !