# Infra Home – NixOS + k3s HA + VLAN + 4G + OpenBao

Homelab perso **entièrement Nixifié** et piloté en GitOps :

- Routeur principal : `rpi4-1` sous **NixOS** (module `modules/roles/router.nix` exposé via `flake.nix`)
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

- Routeur + master k3s (`rpi4-1`) : `10.10.0.1/24` (gateway) **et** `10.10.0.10/24` (IP k3s) sur le VLAN `eth0.10`
- Worker `rpi4-2` : `10.10.0.11/24` (VLAN `eth0.10`) avec passerelle `10.10.0.1`
- Worker `rpi3a-ctl` : `10.10.0.12/24` (Wi-Fi `wlan0`) avec passerelle `10.10.0.1`

`nix flake check` et le script `scripts/check-addressing.sh` valident la cohérence IP/VLAN, les flags k3s et les passerelles.

## Provisionnement sécurisé des PSK Wi-Fi

- Les modules Nix (`modules/roles/router.nix`, `hosts/rpi3a-ctl/configuration.nix`) attendent un fichier runtime
  `/run/secrets/wpa_supplicant.env` qui fournit les variables suivantes (format `KEY=value`) et est injecté
  comme `EnvironmentFile=` de `wpa_supplicant` via `modules/wireless-secrets-compat.nix` :
  - `WAN_4G_PSK` pour le SSID `WAN-4G` (routeur)
  - `INFRA_K3S_PSK` pour le SSID `INFRA-K3S` (worker k3s)
- Ce fichier **ne doit jamais être committé** ni copié dans le store Nix. Générez-le au boot via un composant de secrets
  (ex: `sops-nix` ou un drop-in systemd avec `LoadCredential=/run/secrets/wpa_supplicant.env:/path/chiffré`), idéalement à
  partir d'un artefact chiffré `secrets/wpa_supplicant.env.age`.
- Les placeholders `@WAN_4G_PSK@` et `@INFRA_K3S_PSK@` sont résolus par `networking.wireless.secretsFile` au runtime
  uniquement; l'évaluation Nix reste idempotente et sans fuite de secret.
- Workflow recommandé (GitOps-first):
  1. Stocker le secret chiffré avec SOPS+age dans `secrets/wpa_supplicant.env.age` (non versionné en clair).
  2. Ajouter un module `sops-nix` ou une unité systemd dédiée qui déchiffre vers `/run/secrets/wpa_supplicant.env` (tmpfs)
     avant le démarrage de `wpa_supplicant`.
  3. Laisser Flux/Argo déployer la révision Git; aucune action manuelle sur la machine.

## GitOps k3s (FluxCD/Argo CD)

```
clusters/
  base/                  # Composants communs (namespaces, sources Flux, HelmReleases OpenBao/ESO)
  review|staging|prod/   # Overlays + Kustomization Flux par environnement
```

- `clusters/base/apps/openbao` : HelmRelease + valeurs OpenBao (HA, storage, service).
- Les serveurs k3s `rpi4-1` et `rpi4-2` portent le label `role=infra` via `services.k3s.extraFlags` pour accueillir OpenBao
  conformément au `nodeSelector`/`affinity` du chart; les téléphones/agents n'héritent pas de ce label et restent exclus.
- `scripts/bootstrap-openbao.sh` : initialisation unique OpenBao (pod `openbao-0`
  attendu Ready, unseal + root token à stocker chiffrés via SOPS/age).
- `clusters/base/apps/external-secrets` : HelmRelease ESO + SecretStore/ExternalSecret pilotés par OpenBao.
- `clusters/<env>/flux-system/kustomization.yaml` : Kustomization Flux avec dépendances review → staging → prod.
- Secrets à chiffrer avec **SOPS+age** (fichiers `*.enc.yaml` attendus dans `secrets/`).

Voir `docs/adr/0001-gitops-bootstrap.md` pour les décisions GitOps/approbations.

## Dépendances locales

- `scripts/install-kustomize.sh` : installe **kustomize v5.4.2** dans `./bin/` de façon idempotente (rejouable, sans sudo).
  - Utilise des variables `KUSTOMIZE_VERSION` et `INSTALL_DIR` optionnelles pour épingler la version/emplacement.
  - `make tools` appelle automatiquement ce script avant les lint/tests qui en dépendent.
- Alternativement, `nix develop` fournit déjà `kustomize` via la flake pour éviter toute modification système.

## Cibles reproductibles

- `make test` : lint (pre-commit), `nix flake check`, ShellCheck, `kubeconform`, lint Helm.
- La CI déclenche `tfsec` (action `aquasecurity/tfsec-action@v1.0.3` épinglée) uniquement si des fichiers Terraform versionnés sont
  présents (détection via `git ls-files '*.tf'`).
- `checkov` s'exécute en CI sur `framework=kubernetes` avec `skip-framework=kustomize` pour éviter un bug amont sur les sorties
  multi-documents; les manifests sont ainsi scannés sans rendus kustomize dépendants de binaires externes.
- `make render ENV=review` : génère `dist/review.yaml` depuis `clusters/review` (idem staging/prod).
- `make deploy ENV=staging` : rend le manifest et rappelle de pousser la branche pour déclencher Flux.
- `nix run .#render -- --env prod` : équivalent Nix sans Make (la variable `ENV` peut aussi définir l'environnement, défaut `review`).
- `scripts/deploy-rpi.sh [--ssh] <hostname>` : reconstruit et applique un hôte NixOS (`nixos-rebuild switch --flake .#<hostname>`).
  - Sans `--ssh`, la reconstruction se fait localement; avec `--ssh`, la construction et l'application se font sur l'hôte cible.
- `scripts/deploy-all.sh [--ssh]` : boucle sur `rpi4-1`, `rpi4-2`, `rpi3a-ctl` en appelant `scripts/deploy-rpi.sh` (idempotent, trié).

Les déploiements sont protégés par approbations : promotion `review → staging → prod` via environnements GitHub.

## Notes matérielles

Les fichiers `hosts/*/hardware-configuration.nix` importent un profil matériel minimal (`modules/hardware-placeholder.nix`) pour permettre l’évaluation Nix et la CI sans accès aux machines. Remplace ces placeholders par la sortie complète de `nixos-generate-config` sur chaque hôte avant un déploiement réel.
