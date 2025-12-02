# PHONES

## Principe
Téléphones Android rootés utilisés comme workers k3s ARM connectés au SSID INFRA_K3S (PSK fourni via `/run/secrets/wpa_supplicant.env`).

## Contraintes
- Stabilité Wi-Fi et ressources limitées (CPU/RAM, batterie). Maintenir sur secteur.
- Sécurité physique : considérer ces nœuds comme moins fiables (labels/taints dédiés).

## Étapes de configuration
1. Root + installation d'un agent k3s/klipper-lb compatible ARM.
2. Configurer le token k3s via `/run/secrets/k3s/token` (sops-nix ou LoadCredential).
3. Connecter au SSID INFRA_K3S et vérifier l'adressage INFRA.
4. Affecter des labels/taints spécifiques pour limiter les workloads critiques.
