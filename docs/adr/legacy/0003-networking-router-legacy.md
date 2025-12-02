# ADR-0003 – Retrait du module `modules/networking-router.nix`

- Date : 2024-06-06
- Statut : Déplacé en legacy

## Contexte

Un premier routeur NixOS était implémenté via `modules/networking-router.nix` avec de la configuration en dur (VLAN, règles nftables, DHCP). L'introduction du rôle `roles.router` a rendu ce module obsolète : la topologie réseau et les règles inter-VLAN sont désormais décrites dans `infra/topology.nix` et injectées comme options typées pour garantir le DRY et l'idempotence.

## Décision

- Retirer `modules/networking-router.nix` du flake actif.
- Ne conserver que le rôle `roles.router` comme chemin supporté pour configurer le routeur.
- Documenter la migration et pointer vers ce fichier legacy pour l'historique.

## Conséquences

- Aucun hôte ne doit importer `modules/networking-router.nix` ; seul `roles.router` est supporté.
- Les VLAN, adresses et règles firewall/DNS doivent être définis via `infra/topology.nix` et consommés par `roles.router.vlans`.
- Les déploiements et la CI continuent de valider une unique implémentation (celle du rôle), réduisant les divergences.

## Migration

1. Supprimer toute importation de `modules/networking-router.nix` dans les hôtes ou la flake.
2. Activer `roles.router` dans l'hôte routeur (ex. `hosts/rpi4-1/configuration.nix`) en passant `vlans = topology.vlans` et les paramètres WAN/Wi-Fi via options.
3. Vérifier la cohérence réseau avec `nix flake check` et le script `scripts/check-addressing.sh` avant promotion GitOps.
