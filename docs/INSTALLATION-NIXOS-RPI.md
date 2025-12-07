# Installation de NixOS sur Raspberry Pi - Guide pas à pas

Ce guide vous accompagne dans l'installation de NixOS sur vos Raspberry Pi pour le projet infra-home. Il est conçu pour les techniciens débutants qui n'ont jamais installé NixOS.

## 🎯 Objectif

À la fin de ce guide, vous aurez :
- NixOS installé et fonctionnel sur votre Raspberry Pi
- Un accès SSH configuré pour les déploiements automatisés
- La configuration matérielle générée automatiquement
- Votre Pi prêt à recevoir la configuration infra-home

## 📋 Prérequis

### Matériel nécessaire
- **Raspberry Pi 4** (recommandé 4GB RAM minimum) ou **Raspberry Pi 3A+**
- **Carte microSD** de 32GB minimum (classe 10 ou mieux)
- **Lecteur de carte SD** pour votre ordinateur
- **Câble Ethernet** (pour la configuration initiale)
- **Alimentation** adaptée à votre Pi

### Logiciels nécessaires
- **Raspberry Pi Imager** (téléchargeable sur [rpi.org](https://www.raspberrypi.org/software/))
- **Terminal/PowerShell** sur votre ordinateur d'administration
- **Éditeur de texte** (nano, vim, ou autre)

## 🚀 Étape 1 : Télécharger l'image NixOS

### Option A : Image officielle (recommandée)

```bash
# Télécharger l'image NixOS pour Raspberry Pi 4
wget https://channels.nixos.org/nixos-23.11/latest-nixos-sd-image-aarch64-linux.img.zst

# Décompresser l'image
unzstd latest-nixos-sd-image-aarch64-linux.img.zst
```

### Option B : Via votre navigateur
1. Allez sur https://nixos.org/download.html
2. Cliquez sur "NixOS SD images"
3. Téléchargez l'image pour **aarch64** (ARM 64-bit)
4. Décompressez le fichier `.zst` avec votre outil préféré

## 🔧 Étape 2 : Flasher la carte SD

### Avec Raspberry Pi Imager (méthode simple)

1. **Lancez Raspberry Pi Imager**
2. **Cliquez sur "CHOOSE OS"** → "Use custom" → Sélectionnez votre image NixOS
3. **Cliquez sur "CHOOSE STORAGE"** → Sélectionnez votre carte SD
4. **⚙️ IMPORTANT : Cliquez sur l'icône engrenage** pour configurer :
   - ✅ **Enable SSH** → "Use password authentication"
   - 👤 **Username** : `nixos`
   - 🔑 **Password** : `nixos` (temporaire, sera changé plus tard)
   - 🌐 **Configure WiFi** (optionnel pour la config initiale)
5. **Cliquez sur "WRITE"** et attendez la fin

### Avec dd (méthode avancée)

```bash
# ⚠️ ATTENTION : Vérifiez bien le nom de votre carte SD !
# Remplacez /dev/sdX par le bon périphérique (ex: /dev/sdb)
lsblk  # Pour voir les périphériques disponibles

# Flasher l'image (ATTENTION au nom du périphérique !)
sudo dd if=nixos-sd-image-aarch64-linux.img of=/dev/sdX bs=4M status=progress
sudo sync  # Forcer l'écriture
```

## 🔌 Étape 3 : Premier démarrage

1. **Insérez la carte SD** dans votre Raspberry Pi
2. **Connectez le câble Ethernet** (pour la configuration initiale)
3. **Branchez l'alimentation** - le Pi va démarrer

### Trouver l'adresse IP du Pi

```bash
# Scanner votre réseau local (remplacez par votre plage IP)
nmap -sn 192.168.1.0/24 | grep -B2 "Raspberry\|B8:27:EB"

# Ou regarder dans votre routeur/box Internet
# L'appareil s'appellera probablement "nixos"
```

## 🔐 Étape 4 : Connexion SSH initiale

```bash
# Connexion avec les identifiants temporaires
ssh nixos@IP_DU_PI
# Mot de passe : nixos
```

**🎉 Félicitations !** Vous êtes maintenant connecté à votre Pi sous NixOS.

## ⚙️ Étape 5 : Configuration initiale

### Générer la configuration matérielle

```bash
# Sur le Pi, générer la config hardware
sudo nixos-generate-config --root /mnt

# Copier la configuration vers le répertoire standard
sudo cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/
```

### Configurer SSH avec votre clé publique

```bash
# Sur votre ordinateur d'administration, copier votre clé publique
ssh-copy-id nixos@IP_DU_PI

# Ou manuellement sur le Pi :
mkdir -p ~/.ssh
echo "VOTRE_CLE_PUBLIQUE_SSH" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Configuration réseau de base

```bash
# Sur le Pi, éditer la configuration réseau temporaire
sudo nano /etc/nixos/configuration.nix
```

Ajoutez cette configuration minimale :

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Configuration réseau de base
  networking.hostName = "rpi4-1";  # Changez selon votre machine
  networking.networkmanager.enable = true;
  
  # SSH activé
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";
  
  # Utilisateur admin
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "VOTRE_CLE_PUBLIQUE_SSH"  # Remplacez par votre vraie clé !
    ];
  };
  
  # Sudo sans mot de passe pour l'admin
  security.sudo.wheelNeedsPassword = false;
  
  # Version NixOS
  system.stateVersion = "23.11";
}
```

### Appliquer la configuration

```bash
# Reconstruire le système avec la nouvelle config
sudo nixos-rebuild switch

# Redémarrer pour s'assurer que tout fonctionne
sudo reboot
```

## 🧪 Étape 6 : Test de la configuration

Après le redémarrage :

```bash
# Tester la connexion SSH avec l'utilisateur admin
ssh admin@IP_DU_PI

# Vérifier que sudo fonctionne sans mot de passe
sudo whoami  # Doit afficher "root"

# Vérifier la version NixOS
nixos-version
```

## 📁 Étape 7 : Récupérer la configuration matérielle

Cette étape est cruciale pour intégrer votre Pi dans le projet infra-home :

```bash
# Sur le Pi, afficher la configuration matérielle
cat /etc/nixos/hardware-configuration.nix

# Copier cette sortie dans le fichier correspondant du projet :
# hosts/rpi4-1/hardware-configuration.nix (pour rpi4-1)
# hosts/rpi4-2/hardware-configuration.nix (pour rpi4-2)
# hosts/rpi3a-ctl/hardware-configuration.nix (pour rpi3a-ctl)
```

## ✅ Étape 8 : Intégration dans infra-home

Maintenant que NixOS est installé, vous pouvez :

1. **Copier la configuration matérielle** dans le bon fichier `hosts/*/hardware-configuration.nix`
2. **Modifier la clé SSH** dans `modules/hardening.nix` avec votre clé publique
3. **Déployer la configuration complète** :

```bash
# Depuis votre machine d'administration
cd infra-home
nix develop  # Entrer dans l'environnement de développement

# Déployer sur le Pi (remplacez rpi4-1 par le bon nom)
./scripts/deploy-rpi.sh --ssh rpi4-1
```

## 🔧 Dépannage

### Le Pi ne démarre pas
- ✅ Vérifiez que la carte SD est bien insérée
- ✅ Vérifiez l'alimentation (LED rouge allumée ?)
- ✅ Essayez une autre carte SD
- ✅ Re-flashez l'image

### Impossible de se connecter en SSH
```bash
# Vérifier que SSH est actif sur le Pi
nmap -p 22 IP_DU_PI

# Vérifier les logs SSH
sudo journalctl -u sshd -f
```

### Erreur "Permission denied" en SSH
```bash
# Vérifier les permissions des clés
ls -la ~/.ssh/
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/id_*.pub
```

### Le Pi n'obtient pas d'IP
- ✅ Vérifiez le câble Ethernet
- ✅ Vérifiez que votre routeur fait du DHCP
- ✅ Connectez un écran pour voir les messages de démarrage

## 📚 Ressources utiles

- **Documentation officielle NixOS** : https://nixos.org/manual/nixos/stable/
- **NixOS sur Raspberry Pi** : https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi_4
- **Guide SSH** : https://nixos.wiki/wiki/SSH_public_key_authentication
- **Dépannage réseau** : https://nixos.wiki/wiki/Networking

## 🎯 Prochaines étapes

Une fois cette installation terminée, vous pouvez :
1. Répéter le processus pour vos autres Raspberry Pi
2. Suivre le guide principal [`QUICKSTART.md`](QUICKSTART.md)
3. Déployer votre infrastructure complète avec `make deploy`

---

> 💡 **Conseil** : Gardez une image de votre carte SD une fois la configuration de base terminée. Cela vous permettra de restaurer rapidement en cas de problème !

> ⚠️ **Sécurité** : N'oubliez pas de changer les mots de passe par défaut et de configurer vos propres clés SSH avant de connecter vos Pi à Internet !