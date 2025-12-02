# HOSTS

## Organisation
- `hosts/<hostname>/configuration.nix` : imports modules + options de rôle.
- `hosts/<hostname>/hardware-configuration.nix` : placeholder à remplacer par `nixos-generate-config` sur la machine.
- Les données réseau/rôles proviennent de `infra/topology.nix` via `modules/topology.nix`.

## Rôles disponibles
- `roles.k3s.masterWorker` : nœud k3s master + worker.
- `roles.k3s.controlPlaneOnly` : nœud k3s control-plane avec taint NoSchedule.
- `roles.router` : routeur VLAN/NAT/nftables/DHCP, WAN 4G.
- `roles.hardening` : durcissement SSH/sudo/journald commun.

## Ajouter un hôte
1. Déclarer l'entrée `hosts.<hostname>` dans `infra/topology.nix` (IP, rôle, labels, `clusterInit`/`serverAddr`).
2. Copier un dossier `hosts/<hostname>/` existant et ajuster les options (`roles.k3s.*` ou `roles.router`).
3. Remplacer `hardware-configuration.nix` par la version générée sur l'hôte.
4. Valider avec `nix flake check` puis `scripts/deploy-rpi.sh [--ssh] <hostname>`.

## Rôles k3s des RPi4B
- rpi4-1 et rpi4-2 partagent le rôle `master-worker` (haute disponibilité), rpi3a-ctl est `control-plane-only` Wi-Fi.
