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
