# 🔐 Gestion des secrets

La sécurité du homelab repose sur une stratégie de gestion des secrets à plusieurs niveaux, garantissant qu'aucun secret n'est stocké en clair dans Git ou sur le système de fichiers.

## 🎯 Stratégie globale

- **🔑 SOPS + age** : Chiffrement des artefacts versionnés (`secrets/*.enc.yaml`)
- **🏦 OpenBao** : Coffre-fort runtime pour les secrets Kubernetes
- **🔄 External Secrets Operator** : Synchronisation automatique OpenBao → k8s Secrets
- **📁 tmpfs** : Stockage temporaire sécurisé (`/run/secrets/*`)

### Principe fondamental
> ⚠️ **Règle d'or** : Aucun secret en clair dans Git, le store Nix, ou sur disque persistant

## 📂 Arborescence des secrets runtime

Les secrets sont montés en tmpfs dans `/run/secrets/` pour éviter toute persistance sur disque :

```
/run/secrets/
├── 📶 wpa_supplicant.env           # PSK Wi-Fi (WAN_4G_PSK, INFRA_K3S_PSK)
├── 🔗 k3s/
│   └── token                       # Token serveur k3s pour workers
├── 🏦 openbao/
│   ├── root-token                  # Token root OpenBao (bootstrap)
│   └── unseal-keys                 # Clés de déverrouillage OpenBao
└── 🔄 eso/
    └── openbao-token               # Token ESO pour SecretStore
```

### Types de secrets par composant

| Composant | Secret | Chemin | Usage |
|-----------|--------|--------|-------|
| **Routeur** | PSK 4G | `/run/secrets/wpa_supplicant.env` | Connexion WAN |
| **k3s** | Token cluster | `/run/secrets/k3s/token` | Authentification workers |
| **OpenBao** | Root token | `/run/secrets/openbao/root-token` | Administration initiale |
| **OpenBao** | Unseal keys | `/run/secrets/openbao/unseal-keys` | Déverrouillage automatique |
| **ESO** | Service token | `/run/secrets/eso/openbao-token` | Accès lecture OpenBao |

## 🔄 Workflow de gestion des secrets

### 1. Configuration initiale

```bash
# Générer une clé age personnelle
age-keygen -o ~/.config/age/key.txt
cat ~/.config/age/key.txt.pub

# Ajouter la clé publique à .sops.yaml
vim .sops.yaml
```

### 2. Chiffrement des secrets

```bash
# Créer/éditer un fichier de secrets
sops secrets/wifi-credentials.yaml

# Exemple de contenu (avant chiffrement) :
# wan_4g_psk: "mon-mot-de-passe-4g"
# infra_k3s_psk: "mot-de-passe-wifi-cluster"

# Le fichier est automatiquement chiffré à la sauvegarde
```

### 3. Déploiement automatique

```bash
# Les secrets sont automatiquement déchiffrés par NixOS
# via sops-nix et montés en tmpfs dans /run/secrets/

# Vérification sur un hôte
ssh rpi4-1 "ls -la /run/secrets/"
ssh rpi4-1 "mount | grep tmpfs"
```

### 4. Bootstrap OpenBao

```bash
# Après déploiement du cluster k3s
scripts/bootstrap-openbao.sh

# Vérification
kubectl get pods -n openbao-system
kubectl get secretstores -A
```

## 🛡️ Bonnes pratiques de sécurité

### ✅ À faire
- **Rotation régulière** : Changer les PSK et tokens périodiquement
- **Validation** : Toujours exécuter `make test` avant commit
- **Audit** : Utiliser `trufflehog` pour détecter les fuites
- **Backup** : Sauvegarder les clés age de manière sécurisée

### ❌ À éviter
- Secrets en clair dans les options Nix
- Secrets dans les manifests Kustomize
- Secrets dans les logs CI/CD
- Stockage persistant des secrets déchiffrés

### 🔍 Commandes de vérification

```bash
# Scan des secrets dans le dépôt
trufflehog git file://. --only-verified

# Vérification des permissions tmpfs
ssh rpi4-1 "ls -la /run/secrets/ && mount | grep /run/secrets"

# Test de déchiffrement
sops -d secrets/wifi-credentials.yaml

# Validation des SecretStores
kubectl get secretstores -A -o yaml
kubectl get externalsecrets -A
```

## 🆘 Dépannage

### Problème : Secret non déchiffré
```bash
# Vérifier la clé age
age --version
ls ~/.config/age/

# Vérifier .sops.yaml
cat .sops.yaml

# Test manuel
sops -d secrets/wifi-credentials.yaml
```

### Problème : OpenBao sealed
```bash
# Vérifier l'état
kubectl exec -n openbao-system openbao-0 -- vault status

# Re-bootstrap si nécessaire
scripts/bootstrap-openbao.sh
```

### Problème : ESO ne synchronise pas
```bash
# Logs External Secrets Operator
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets

# Vérifier les SecretStores
kubectl describe secretstore -A
```
