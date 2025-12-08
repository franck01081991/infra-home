# 🚀 Guide de démarrage rapide

Ce guide vous accompagne dans la mise en place complète du homelab, de l'installation de Nix au déploiement du cluster k3s.

## 📋 Prérequis

### Système hôte
- **Nix** installé avec les flakes activés
- **Git** configuré avec accès au dépôt
- **SSH** configuré avec clés publiques déployées sur les RPi

### Matériel requis
- **Raspberry Pi 4B** (rpi4-1) : routeur principal, 4GB+ RAM recommandé
- **Raspberry Pi 4B** (rpi4-2) : worker filaire, 2GB+ RAM
- **Raspberry Pi 3A+** (rpi3a-ctl) : worker Wi-Fi, control-plane uniquement
- **Carte SD** : 32GB+ par machine, classe 10 minimum
- **Connectivité** : accès 4G/Wi-Fi pour rpi4-1, Ethernet pour rpi4-2

### Secrets et authentification
- **Clés age** : pour déchiffrer les artefacts SOPS
- **Accès GitHub** : pour pousser les manifestes rendus
- **PSK Wi-Fi** : pour les réseaux WAN 4G et INFRA_K3S

## 🔧 Installation de Nix (si nécessaire)

```bash
# Installation Nix avec flakes (Linux/macOS)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Ou installation manuelle
sh <(curl -L https://nixos.org/nix/install) --daemon

# Activation des flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

## 🛠️ Configuration de l'environnement de développement

```bash
# Cloner le dépôt
git clone git@github.com:franck01081991/infra-home.git
cd infra-home

# Validation de la configuration
nix flake check      # valide modules, topologie, options NixOS
make test            # lint + kubeconform + scans de sécurité

# Vérification des outils disponibles
kubectl version --client
flux version --client
helm version
age --version
```

## 🖥️ Préparation et déploiement des hôtes NixOS

### Étape 1 : Installation NixOS de base

```bash
# Sur chaque Raspberry Pi, installer NixOS minimal
# Puis générer la configuration matérielle
sudo nixos-generate-config --root /mnt

# Copier hardware-configuration.nix vers le dépôt
scp /mnt/etc/nixos/hardware-configuration.nix user@dev-machine:~/infra-home/hosts/rpi4-1/
```

### Étape 2 : Configuration des secrets

```bash
# Générer une clé age (si pas déjà fait)
age-keygen -o ~/.config/age/key.txt

# Ajouter la clé publique à .sops.yaml
# Puis éditer les secrets
sops secrets/openbao.yaml
sops secrets/wifi-credentials.yaml
```

### Étape 3 : Déploiement

```bash
# Déploiement d'un hôte spécifique
scripts/deploy-rpi.sh --ssh rpi4-1

# Déploiement de tous les hôtes
scripts/deploy-all.sh --ssh

# Vérification du déploiement
ssh rpi4-1 "systemctl status k3s"
```

> ⚠️ **Important** : Remplacez `hosts/<hôte>/hardware-configuration.nix` par la sortie de `nixos-generate-config` avant le premier déploiement.

## ⚙️ Pipeline GitOps avec FluxCD

### Configuration initiale de Flux

```bash
# Vérifier que le cluster k3s est accessible
kubectl get nodes

# Bootstrap Flux sur le cluster
flux bootstrap github \
  --owner=franck01081991 \
  --repository=infra-home \
  --branch=main \
  --path=clusters/base

# Vérifier l'installation
flux get kustomizations
kubectl get pods -n flux-system
```

### Déploiement par environnement

```bash
# Environnement de review (test)
make render ENV=review   # génère dist/review.yaml
make deploy ENV=review   # render + push Git automatique

# Environnement staging
make render ENV=staging
make deploy ENV=staging

# Production (après validation)
make render ENV=prod
make deploy ENV=prod

# Alternative avec Nix
nix run .#render -- --env staging
```

### Pipeline de promotion

Les Kustomizations Flux s'enchaînent automatiquement :
```
review → staging → prod
```

> 📋 **Référence** : Voir [ADR 0001](adr/0001-gitops-bootstrap.md) pour les détails du pipeline GitOps.

## 🔐 Configuration d'OpenBao (gestionnaire de secrets)

### Étape 1 : Déploiement via Flux

```bash
# Vérifier que OpenBao et ESO sont déployés
kubectl get pods -n openbao-system
kubectl get pods -n external-secrets-system

# Si pas encore déployé, forcer la synchronisation
flux reconcile kustomization apps
```

### Étape 2 : Bootstrap initial

```bash
# Déchiffrer les artefacts SOPS (automatique via NixOS)
# Les secrets sont montés dans /run/secrets/openbao/* et /run/secrets/eso/

# Exécuter le script de bootstrap (idempotent)
scripts/bootstrap-openbao.sh

# Vérifier l'état d'OpenBao
kubectl exec -n openbao-system openbao-0 -- vault status
```

### Étape 3 : Configuration des SecretStores

```bash
# Appliquer les SecretStore et ExternalSecret
kubectl apply -f clusters/base/secrets/

# Vérifier la synchronisation
kubectl get secretstores -A
kubectl get externalsecrets -A
```

## 🎉 Vérification finale

```bash
# Cluster k3s
kubectl get nodes -o wide
kubectl get pods -A

# Services réseau
ssh rpi4-1 "ip addr show"
ssh rpi4-1 "nft list ruleset"

# FluxCD
flux get all

# OpenBao
kubectl get secrets -A | grep openbao
```

## 🆘 Dépannage courant

### Problèmes de connectivité
```bash
# Vérifier les VLANs
ssh rpi4-1 "ip link show | grep vlan"

# Tester la connectivité inter-nœuds
kubectl get nodes -o wide
ping 10.10.0.11  # rpi4-2
```

### Problèmes FluxCD
```bash
# Logs Flux
kubectl logs -n flux-system -l app=source-controller
kubectl logs -n flux-system -l app=kustomize-controller

# Forcer la réconciliation
flux reconcile source git flux-system
```

### Problèmes OpenBao
```bash
# Vérifier l'état du vault
kubectl exec -n openbao-system openbao-0 -- vault status

# Logs OpenBao
kubectl logs -n openbao-system openbao-0
```

---

🎯 **Prochaines étapes** : Consultez la [documentation complète](../README.md#-documentation) pour approfondir la configuration réseau, la gestion des secrets, et l'ajout de workers Android.
