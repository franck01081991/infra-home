# Infra Home – NixOS + k3s HA + VLAN + 4G + OpenBao

Homelab perso **entièrement Nixifié** et piloté en GitOps :

- Routeur principal : `rpi4-1` sous **NixOS**
- WAN via **modem 4G** (Wi-Fi)
- Cœur de calcul : **cluster k3s HA** (rpi4-1, rpi4-2, rpi3a-ctl)
- 3 téléphones Android **rootés** comme **workers ARM**
- **Segmentation réseau avancée** via VLAN : INFRA / PRO / PERSO / IOT
- **OpenBao** dans k3s pour la gestion des secrets
- **External Secrets Operator** pour sync OpenBao → Secrets k8s
- Code infra **déclaratif** via flake Nix + manifests FluxCD dans `clusters/*`

Ce dépôt reste un PoC MSP / DevOps mais tous les déploiements passent désormais par FluxCD/Argo CD :
les cibles `make`/`nix run` génèrent le manifest final, qu'on versionne puis que Flux applique. La vue d'ensemble
de l'arborescence (flake, modules, hôtes, clusters, secrets, scripts) et du flux GitOps est décrite dans
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), en complément de l'ADR [0001](docs/adr/0001-gitops-bootstrap.md).

## Plan d'adressage (INFRA VLAN 10)

- Routeur : `10.10.0.1/24` (VLAN `eth0.10`)
- Master k3s (`rpi4-1`) : `10.10.0.10/24` (VLAN `eth0.10`) avec passerelle `10.10.0.1`
- Worker `rpi4-2` : `10.10.0.11/24` (VLAN `eth0.10`) avec passerelle `10.10.0.1`
- Worker `rpi3a-ctl` : `10.10.0.12/24` (Wi-Fi `wlan0`) avec passerelle `10.10.0.1`

`nix flake check` et le script `scripts/check-addressing.sh` valident la cohérence IP/VLAN, les flags k3s et les passerelles.

## GitOps k3s (FluxCD/Argo CD)

```
clusters/
  base/                  # Composants communs (namespaces, sources Flux, HelmReleases OpenBao/ESO)
  review|staging|prod/   # Overlays + Kustomization Flux par environnement
```

- `clusters/base/apps/openbao` : HelmRelease + valeurs OpenBao (HA, storage, service).
- `clusters/base/apps/external-secrets` : HelmRelease ESO + SecretStore/ExternalSecret pilotés par OpenBao.
- `clusters/<env>/flux-system/kustomization.yaml` : Kustomization Flux avec dépendances review → staging → prod.
- Secrets à chiffrer avec **SOPS+age** (fichiers `*.enc.yaml` attendus dans `secrets/`).

Voir `docs/adr/0001-gitops-bootstrap.md` pour les décisions GitOps/approbations.

## Cibles reproductibles

- `make test` : lint (pre-commit), `nix flake check`, ShellCheck, `kubeconform`, lint Helm.
- `make render ENV=review` : génère `dist/review.yaml` depuis `clusters/review` (idem staging/prod).
- `make deploy ENV=staging` : rend le manifest et rappelle de pousser la branche pour déclencher Flux.
- `nix run .#render -- --env prod` : équivalent Nix sans Make.

Les déploiements sont protégés par approbations : promotion `review → staging → prod` via environnements GitHub.

## Notes matérielles

Les fichiers `hosts/*/hardware-configuration.nix` importent un profil matériel minimal (`modules/hardware-placeholder.nix`) pour permettre l’évaluation Nix et la CI sans accès aux machines. Remplace ces placeholders par la sortie complète de `nixos-generate-config` sur chaque hôte avant un déploiement réel.
