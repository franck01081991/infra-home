# Infra Home – Homelab NixOS + k3s HA + VLAN + 4G + OpenBao

Homelab GitOps-first avec routeur NixOS (rpi4-1) connecté en 4G, cluster k3s haute disponibilité (rpi4-1 master/worker, rpi4-2 worker filaire, rpi3a-ctl worker Wi-Fi) et téléphones Android rootés comme workers ARM. Le réseau est segmenté en VLANs (INFRA/PRO/PERSO/IOT), les secrets sont gérés par OpenBao + External Secrets Operator, et l'état désiré est versionné avec des flakes Nix et des manifestes FluxCD.

## 🎯 Objectifs du projet

- **Infrastructure as Code** : Configuration complète en Nix, déploiements reproductibles
- **GitOps** : Pipeline automatisé avec FluxCD (review → staging → prod)
- **Sécurité** : Segmentation réseau VLAN, gestion centralisée des secrets
- **Haute disponibilité** : Cluster k3s multi-nœuds avec basculement automatique
- **Mobilité** : Connectivité 4G et workers mobiles (téléphones Android)

## 🚀 Démarrage rapide

```bash
# Cloner le dépôt
git clone git@github.com:franck01081991/infra-home.git
cd infra-home

# Environnement de développement (kubectl, flux, helm, age, linters…)
nix develop

# Validation de la configuration
nix flake check      # valide modules et topologie
make test            # lint/kubeconform/scans de sécurité

# Déploiement d'un hôte NixOS
ssh rpi4-1 && scripts/deploy-rpi.sh --ssh rpi4-1

# Pipeline GitOps local
make render ENV=review && make deploy ENV=review
```

> 💡 **Prérequis** : Nix avec flakes activés, accès SSH aux hôtes, clés age pour SOPS

## 🖥️ Architecture des machines

| Machine | Rôle | Connectivité | Adresse IP |
|---------|------|--------------|------------|
| **rpi4-1** | Routeur + k3s master/worker | 4G WAN (Wi-Fi) | 10.10.0.1 (gateway) + 10.10.0.10 (k3s) |
| **rpi4-2** | k3s worker | Ethernet | 10.10.0.11/24 |
| **rpi3a-ctl** | k3s worker (control-plane-only) | Wi-Fi | 10.10.0.12/24 |
| **Téléphones Android** | k3s workers ARM | Wi-Fi (SSID INFRA_K3S) | DHCP 10.10.0.x |

### Segmentation réseau (VLANs)

- **🏗️ INFRA (VLAN 10)** : `10.10.0.0/24` - Infrastructure k3s, routeur
- **💼 PRO (VLAN 20)** : `10.20.0.0/24` - Environnement professionnel
- **🏠 PERSO (VLAN 30)** : `10.30.0.0/24` - Réseau personnel
- **🌐 IOT (VLAN 40)** : `10.40.0.0/24` - Objets connectés

## 📁 Structure du projet

```
infra-home/
├── 📄 flake.nix                    # Point d'entrée Nix, devshell
├── 📁 nix/                         # Configuration Nix, packages
├── 📁 modules/                     # Modules NixOS réutilisables
│   ├── router.nix                  # Configuration routeur (VLAN, NAT, nftables)
│   ├── k3s.nix                     # Cluster k3s (master/worker)
│   └── hardening.nix               # Durcissement sécurité
├── 📁 hosts/                       # Configuration par machine
│   ├── rpi4-1/                     # Routeur principal
│   ├── rpi4-2/                     # Worker filaire
│   └── rpi3a-ctl/                  # Worker Wi-Fi
├── 📁 infra/
│   └── topology.nix                # Source unique : VLANs/hosts/rôles
├── 📁 clusters/                    # Manifestes FluxCD
│   ├── base/                       # Configuration de base
│   ├── review/                     # Environnement de test
│   ├── staging/                    # Pré-production
│   └── prod/                       # Production
├── 📁 k8s/                         # Manifestes legacy (référence)
├── 📁 scripts/                     # Scripts de déploiement
│   ├── deploy-rpi.sh               # Déploiement NixOS
│   ├── deploy-all.sh               # Déploiement multi-hôtes
│   └── bootstrap-openbao.sh        # Configuration OpenBao
├── 📁 secrets/                     # Artefacts chiffrés SOPS/age
└── 📁 docs/                        # Documentation détaillée
```

## 📚 Documentation

### Guides pratiques
- **🚀 Démarrage rapide** : [`docs/QUICKSTART.md`](docs/QUICKSTART.md) - Installation et premiers pas
- **🌐 Réseau** : [`docs/NETWORKING.md`](docs/NETWORKING.md) - VLANs, routage, Wi-Fi
- **⚙️ GitOps/Flux** : [`docs/GITOPS.md`](docs/GITOPS.md) - Pipeline CI/CD, déploiements
- **🔐 Secrets** : [`docs/SECRETS.md`](docs/SECRETS.md) - OpenBao, SOPS, External Secrets
- **🖥️ Hôtes** : [`docs/HOSTS.md`](docs/HOSTS.md) - Configuration des machines
- **📱 Téléphones** : [`docs/PHONES.md`](docs/PHONES.md) - Workers Android rootés

### Architecture et décisions
- **🏗️ Architecture** : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - Vue d'ensemble du système
- **📋 ADRs** : Décisions d'architecture
  - [`0001-gitops-bootstrap.md`](docs/adr/0001-gitops-bootstrap.md) - Bootstrap GitOps
  - [`0002-topology-datasource.md`](docs/adr/0002-topology-datasource.md) - Source de vérité topologie

## 🛠️ Commandes utiles

```bash
# Validation complète
make test                           # lint + kubeconform + scans sécurité
nix flake check                     # validation modules Nix

# Déploiement NixOS
scripts/deploy-rpi.sh --ssh rpi4-1  # déploiement distant
scripts/deploy-all.sh --ssh         # tous les hôtes

# Pipeline GitOps
make render ENV=review              # génération manifestes
make deploy ENV=review              # déploiement + push Git
nix run .#render -- --env staging   # alternative Nix

# Gestion des secrets
sops secrets/openbao.yaml          # édition secrets OpenBao
age-keygen -o ~/.config/age/key.txt # génération clé age
```

## 🔧 Technologies utilisées

- **🐧 NixOS** : Configuration système déclarative et reproductible
- **☸️ k3s** : Distribution Kubernetes légère pour ARM/x86
- **🔄 FluxCD** : GitOps pour déploiements automatisés
- **🔐 OpenBao** : Gestionnaire de secrets (fork HashiCorp Vault)
- **🔑 SOPS + age** : Chiffrement des secrets dans Git
- **🌐 nftables** : Pare-feu et routage avancé
- **📱 Android** : Workers mobiles avec Termux + k3s
