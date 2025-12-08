# Environnement Docker pour infra-home

Ce guide vous explique comment utiliser l'environnement Docker pour travailler avec infra-home **sans installer Nix** sur votre machine locale.

## 🎯 Pourquoi utiliser Docker ?

L'environnement Docker est parfait si :
- ✅ Vous ne souhaitez pas installer Nix sur votre machine
- ✅ Vous travaillez sous Windows ou macOS
- ✅ Vous voulez un environnement isolé et reproductible
- ✅ Vous préférez une installation "clé en main"

## 📋 Prérequis

- **Docker** installé sur votre machine ([docker.com](https://www.docker.com/get-started))
- **Docker Compose** (inclus avec Docker Desktop)
- **Git** pour cloner le repository

## 🚀 Démarrage rapide

### 1. Cloner le repository

```bash
git clone https://github.com/franck01081991/infra-home.git
cd infra-home
```

### 2. Configurer vos informations Git (optionnel)

```bash
# Créer un fichier .env pour vos paramètres personnels
cat > .env << EOF
GIT_USER_NAME="Votre Nom"
GIT_USER_EMAIL="votre.email@example.com"
EOF
```

### 3. Lancer l'environnement

```bash
# Construire et lancer le conteneur
docker-compose up -d

# Entrer dans l'environnement de développement
docker-compose exec infra-home bash
```

🎉 **Vous êtes maintenant dans l'environnement infra-home !**

## 🛠️ Utilisation

Une fois dans le conteneur, vous avez accès à tous les outils :

```bash
# Valider la configuration
nix flake check

# Lancer les tests
make test

# Générer les manifestes pour l'environnement de review
make render ENV=review

# Déployer sur un Raspberry Pi (si accessible)
./scripts/deploy-rpi.sh --ssh rpi4-1

# Voir l'aide des scripts
./scripts/deploy-rpi.sh --help
```

## 🔑 Configuration SSH

### Méthode automatique (recommandée)

Vos clés SSH locales (`~/.ssh/`) sont automatiquement montées dans le conteneur. Aucune configuration supplémentaire n'est nécessaire.

### Méthode manuelle

Si vous préférez utiliser des clés spécifiques :

```bash
# Copier vos clés dans le conteneur
docker cp ~/.ssh/id_rsa infra-home-dev:/home/nixuser/.ssh/
docker cp ~/.ssh/id_rsa.pub infra-home-dev:/home/nixuser/.ssh/

# Entrer dans le conteneur et configurer les permissions
docker-compose exec infra-home bash
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

## 📁 Structure des volumes

```
Votre machine          →  Conteneur
./                     →  /workspace          # Code source
~/.ssh/                →  /ssh-keys          # Clés SSH (lecture seule)
nix-cache (volume)     →  /nix               # Cache Nix persistant
```

## 🔧 Commandes utiles

### Gestion du conteneur

```bash
# Démarrer l'environnement
docker-compose up -d

# Entrer dans le conteneur
docker-compose exec infra-home bash

# Voir les logs
docker-compose logs -f

# Arrêter l'environnement
docker-compose down

# Reconstruire l'image (après mise à jour)
docker-compose build --no-cache
```

### Exécution de commandes directes

```bash
# Exécuter une commande sans entrer dans le conteneur
docker-compose exec infra-home nix flake check
docker-compose exec infra-home make test

# Ou en une ligne
docker-compose run --rm infra-home make render ENV=review
```

## 🐛 Dépannage

### Le conteneur ne démarre pas

```bash
# Vérifier les logs
docker-compose logs infra-home

# Vérifier que Docker fonctionne
docker --version
docker-compose --version
```

### Erreur "flake.nix not found"

Assurez-vous d'être dans le répertoire `infra-home` avant de lancer Docker Compose :

```bash
pwd  # Doit afficher .../infra-home
ls   # Doit montrer flake.nix, README.md, etc.
```

### Problèmes de permissions SSH

```bash
# Dans le conteneur, vérifier les permissions
ls -la ~/.ssh/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
```

### Cache Nix corrompu

```bash
# Supprimer le volume de cache et reconstruire
docker-compose down
docker volume rm infra-home_nix-cache
docker-compose up -d
```

### Connectivité réseau vers les Raspberry Pi

Le conteneur utilise le réseau host, donc il devrait pouvoir accéder à vos Pi. Vérifiez :

```bash
# Dans le conteneur
ping 192.168.1.100  # Remplacez par l'IP de votre Pi
ssh admin@192.168.1.100  # Test de connexion SSH
```

## 🔄 Mise à jour

Pour mettre à jour l'environnement Docker :

```bash
# Arrêter le conteneur
docker-compose down

# Mettre à jour le code
git pull

# Reconstruire l'image
docker-compose build --no-cache

# Redémarrer
docker-compose up -d
```

## 💡 Conseils et bonnes pratiques

### Performance

- Le **cache Nix** est persistant entre les redémarrages
- La première construction peut prendre **10-15 minutes**
- Les lancements suivants sont **beaucoup plus rapides**

### Sécurité

- Les clés SSH sont montées en **lecture seule**
- Le conteneur utilise un **utilisateur non-root**
- Aucun port n'est exposé par défaut

### Workflow recommandé

1. **Développement** : Modifiez les fichiers sur votre machine locale
2. **Tests** : Exécutez les commandes dans le conteneur
3. **Déploiement** : Utilisez les scripts depuis le conteneur

## 🆚 Docker vs Nix natif

| Aspect | Docker | Nix natif |
|--------|--------|-----------|
| **Installation** | Simple (Docker uniquement) | Plus complexe (Nix + config) |
| **Performance** | Légèrement plus lent | Plus rapide |
| **Isolation** | Excellente | Bonne |
| **Portabilité** | Windows/macOS/Linux | Principalement Linux/macOS |
| **Maintenance** | Automatique | Manuelle |

## 📚 Prochaines étapes

Une fois l'environnement configuré :

1. Suivez le guide [`INSTALLATION-NIXOS-RPI.md`](INSTALLATION-NIXOS-RPI.md) pour préparer vos Pi
2. Consultez [`QUICKSTART.md`](QUICKSTART.md) pour déployer votre infrastructure
3. Explorez [`NETWORKING.md`](NETWORKING.md) pour comprendre la configuration réseau

---

> 💡 **Astuce** : Vous pouvez utiliser votre éditeur favori sur votre machine locale pour modifier les fichiers. Les changements sont automatiquement synchronisés dans le conteneur !

> 🔧 **Support** : En cas de problème, consultez d'abord la section dépannage ci-dessus, puis ouvrez une issue sur GitHub.