# Infra Home – Homelab NixOS + k3s HA + VLAN + 4G + OpenBao

Homelab GitOps-first : routeur NixOS (rpi4-1) avec WAN 4G + cluster k3s HA (rpi4-1 master/worker, rpi4-2 worker filaire, rpi3a-ctl worker Wi-Fi) et téléphones Android rootés comme workers ARM. Réseau segmenté en VLAN (INFRA/PRO/PERSO/IOT), secrets gérés par OpenBao + External Secrets Operator, état désiré versionné (flake Nix + manifests FluxCD).

## TL;DR
```bash
git clone git@github.com:franck01081991/infra-home.git
cd infra-home
nix develop          # devshell : kubectl, flux, helm, age, linters…
nix flake check      # valide modules et topologie
make test            # lint/kubeconform/scans
auth ssh rpi4-1 && scripts/deploy-rpi.sh --ssh rpi4-1  # exemple déploiement host
make render ENV=review && make deploy ENV=review        # pipeline GitOps local
```

## Rôles des machines
- **rpi4-1** : routeur + master/worker k3s, WAN 4G (Wi-Fi).
- **rpi4-2** : worker k3s filaire.
- **rpi3a-ctl** : worker k3s Wi-Fi.
- **Téléphones Android rootés** : workers k3s ARM (SSID INFRA_K3S).

## Arborescence (extrait)
- `flake.nix`, `nix/` : flake et devshell.
- `modules/` : rôles NixOS (router, k3s, hardening…).
- `hosts/<hôte>/` : configuration par machine (placeholders matériels à remplacer).
- `infra/topology.nix` : source unique VLAN/hosts/rôles.
- `clusters/base|review|staging|prod` : manifests FluxCD.
- `k8s/` : manifestes legacy non appliqués par Flux (voir `docs/GITOPS.md`).
- `scripts/` : render/deploy, bootstrap OpenBao, build téléphones.
- `secrets/` : artefacts chiffrés SOPS/age.
- `docs/` : guides thématiques, architecture, ADR.

## Documentation
- Quickstart : [`docs/QUICKSTART.md`](docs/QUICKSTART.md)
- Réseau : [`docs/NETWORKING.md`](docs/NETWORKING.md)
- GitOps/Flux : [`docs/GITOPS.md`](docs/GITOPS.md)
- Secrets : [`docs/SECRETS.md`](docs/SECRETS.md)
- Hôtes : [`docs/HOSTS.md`](docs/HOSTS.md)
- Téléphones : [`docs/PHONES.md`](docs/PHONES.md)
- Architecture : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- ADR : [`docs/adr/0001-gitops-bootstrap.md`](docs/adr/0001-gitops-bootstrap.md), [`docs/adr/0002-topology-datasource.md`](docs/adr/0002-topology-datasource.md)
