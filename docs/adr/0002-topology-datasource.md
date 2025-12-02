# ADR 0002 – Source unique pour la topologie réseau et les rôles NixOS

## Contexte

Les adresses IP k3s, les VLAN et les rôles (router / master-worker / control-plane-only)
étaient définis en dur dans `flake.nix`, `hosts/*/configuration.nix` et
`modules/roles/router.nix`, au risque de divergences lors de l'ajout de nouveaux
hôtes ou de la modification des VLAN.

## Décision

- Introduire `infra/topology.nix` comme **source unique** décrivant :
  - La liste des VLAN (ID, sous-réseau, adresses du routeur, plages DHCP,
    règles d'ingress/forward dnsmasq + nftables).
  - Les hôtes NixOS (rôles, adresses IP par VLAN, labels/taints k3s,
    indicateur `clusterInit`).
  - Les paramètres globaux k3s (SAN API, `serverAddr`).
- Ajouter le module `modules/topology.nix` qui injecte ces données via
  `_module.args.topology` dans chaque `nixosSystem` du flake.
- Refactorer `hosts/*/configuration.nix` pour consommer exclusivement
  `topology.vlans` et `topology.hosts.<hostname>` sans valeurs réseau en dur.

## Conséquences

- DRY : toute évolution IP/VLAN/roles se fait dans `infra/topology.nix` et est
  propagée automatiquement aux hôtes et aux modules router/k3s.
- Cohérence auditée : une revue Git suffit à valider un changement d'adressage
  ou de rôle ; plus de risques de désalignement entre les hôtes.
- Extensibilité : l'ajout d'un hôte se fait en trois étapes GitOps-only :
  1. Déclarer l'entrée `hosts.<nouvel-hôte>` dans `infra/topology.nix`.
  2. Ajouter `hosts/<nouvel-hôte>/configuration.nix` qui consomme cette entrée.
  3. Laisser la CI/Flux appliquer la nouvelle configuration.
- Documentation : `README.md` référence désormais la convention et `infra/topology.nix`
  doit être tenu à jour à chaque changement réseau.
