# Infra Home – NixOS + k3s HA + VLAN + 4G + OpenBao

Homelab perso **entièrement Nixifié** :

- Routeur principal : `rpi4-1` sous **NixOS**
- WAN via **modem 4G** (Wi-Fi)
- Cœur de calcul : **cluster k3s HA** (rpi4-1, rpi4-2, rpi3a-ctl)
- 3 téléphones Android **rootés** comme **workers ARM**
- **Segmentation réseau avancée** via VLAN : INFRA / PRO / PERSO / IOT
- **OpenBao** dans k3s pour la gestion des secrets
- **External Secrets Operator** pour sync OpenBao → Secrets k8s
- Code infra **déclaratif** via flake Nix

Ce dépôt est le PoC de ton futur projet MSP / DevOps.

(Le reste de la doc est à compléter selon tes besoins spécifiques.)

Voir les fichiers NixOS et k8s pour la configuration détaillée.

## Plan d'adressage (INFRA VLAN 10)

- Routeur : `10.10.0.1/24` (VLAN `eth0.10`)
- Master k3s (`rpi4-1`) : `10.10.0.10/24` (VLAN `eth0.10`) avec passerelle `10.10.0.1`
- Worker `rpi4-2` : `10.10.0.11/24` (VLAN `eth0.10`) avec passerelle `10.10.0.1`
- Worker `rpi3a-ctl` : `10.10.0.12/24` (Wi-Fi `wlan0`) avec passerelle `10.10.0.1`

Le script `scripts/check-addressing.sh` et le job GitHub Actions `ci` vérifient la cohérence de cet adressage (IP/VLAN, flags k3s, passerelles) via `nix flake check` + validations dédiées.

## Notes matérielles (placeholders CI)

Les fichiers `hosts/*/hardware-configuration.nix` importent un profil matériel minimal (`modules/hardware-placeholder.nix`) pour permettre l’évaluation Nix et la CI sans accès aux machines. Remplace ces placeholders par la sortie complète de `nixos-generate-config` sur chaque hôte avant un déploiement réel.
