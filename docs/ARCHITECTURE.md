# 🏗️ Architecture du homelab

## 🎯 Vue d'ensemble

Le homelab implémente une architecture moderne basée sur l'Infrastructure as Code, combinant :

- **🐧 NixOS** : Configuration système déclarative et reproductible
- **☸️ k3s** : Cluster Kubernetes haute disponibilité sur ARM
- **🔄 GitOps** : Déploiements automatisés avec FluxCD
- **🔐 Zero-trust** : Segmentation réseau et gestion centralisée des secrets

## 🌐 Topologie réseau

```
Internet (4G)
     │
┌────▼────┐     ┌─────────────┐     ┌─────────────┐
│ rpi4-1  │────▶│   rpi4-2    │     │  rpi3a-ctl  │
│ Routeur │     │   Worker    │     │   Worker    │
│ Master  │     │  (Ethernet) │     │   (Wi-Fi)   │
└─────────┘     └─────────────┘     └─────────────┘
     │
┌────▼────────────────────────────────────────────┐
│              VLANs segmentés                    │
│  INFRA(10) │ PRO(20) │ PERSO(30) │ IOT(40)     │
└─────────────────────────────────────────────────┘
     │
┌────▼────┐
│📱 Phones│
│ Workers │
└─────────┘
```

## 🔄 Pipeline GitOps

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   review    │───▶│   staging    │───▶│    prod     │
│ (test/dev)  │    │ (validation) │    │ (production)│
└─────────────┘    └──────────────┘    └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────┐
│              FluxCD Reconciliation                  │
│         clusters/base → review → staging → prod     │
└─────────────────────────────────────────────────────┘
```

## 🔐 Architecture des secrets

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│    SOPS     │───▶│   OpenBao    │───▶│ k8s Secrets │
│  (Git/age)  │    │  (Runtime)   │    │   (ESO)     │
└─────────────┘    └──────────────┘    └─────────────┘
       │                   │                   │
   Versioned           Centralized          Distributed
   Encrypted            Vault               Applications
```

## 📚 Documentation détaillée

### Guides opérationnels
- **🌐 Réseau** : [`NETWORKING.md`](NETWORKING.md) - VLANs, routage, connectivité
- **⚙️ GitOps** : [`GITOPS.md`](GITOPS.md) - Pipeline CI/CD, déploiements
- **🔐 Secrets** : [`SECRETS.md`](SECRETS.md) - SOPS, OpenBao, ESO
- **🖥️ Hôtes** : [`HOSTS.md`](HOSTS.md) - Configuration des machines
- **📱 Téléphones** : [`PHONES.md`](PHONES.md) - Workers Android

### Décisions d'architecture (ADRs)
- **📋 ADR-0001** : [`gitops-bootstrap.md`](adr/0001-gitops-bootstrap.md) - Bootstrap GitOps
- **📋 ADR-0002** : [`topology-datasource.md`](adr/0002-topology-datasource.md) - Source de vérité topologie

## 🎯 Avantages de cette architecture

- **🔄 Reproductibilité** : Configuration complète en code (Nix + Git)
- **🛡️ Sécurité** : Segmentation réseau + secrets chiffrés
- **📈 Scalabilité** : Ajout facile de workers (RPi + téléphones)
- **🔧 Maintenabilité** : GitOps + validation automatisée
- **💰 Économique** : Matériel ARM low-cost + connectivité 4G
