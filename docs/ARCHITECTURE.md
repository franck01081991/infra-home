# Architecture et arborescence GitOps

Ce dépôt regroupe la configuration NixOS et Kubernetes pilotée par FluxCD. Les dossiers sont pensés pour rester DRY vis-à-vis de l'ADR [0001 – GitOps FluxCD + approbations review → staging → prod](adr/0001-gitops-bootstrap.md) et des cibles `make`/`nix` existantes.

## Arborescence logique

- **Flake Nix** (`flake.nix`) : point d'entrée pour les configurations NixOS (`nixosConfigurations`) et l'app `render` utilisée par `nix run .#render`.
- **Modules NixOS** (`modules/`) : briques réutilisables (réseau, k3s, durcissement) importées par chaque hôte.
- **Hôtes** (`hosts/<nom>/configuration.nix`) : déclarations par machine, qui composent les modules communs ; les fichiers `hardware-configuration.nix` sont des placeholders pour la CI.
- **Clusters Kubernetes (FluxCD)** (`clusters/`) : base commune (`clusters/base`) avec namespaces et sources Flux, puis overlays par environnement (`review`, `staging`, `prod`) déclarant les `Kustomization` Flux dépendantes.
- **Secrets** (`secrets/`) : fichiers chiffrés attendus via SOPS+age ou SealedSecrets (jamais en clair). Les valeurs consommées par Flux doivent être rendues chiffrées avant commit.
- **Scripts** (`scripts/`) : automatisations idempotentes (`render-desired-state.sh` pour générer `dist/<env>.yaml`, validation d'adressage, build images téléphone, bootstrap OpenBao).

## Flux GitOps (render → commit → Flux)

1. **Render local** : `make render ENV=<env>` ou `nix run .#render -- --env <env>` construit l'état désiré (Kustomize) dans `dist/<env>.yaml` à partir de `clusters/<env>`.
2. **Validation locale** : `make test` (ou équivalent Nix) applique les lint/CI locales (pre-commit, kubeconform, Helm lint, ShellCheck) pour rester aligné avec la pipeline.
3. **Commit & PR** : les manifest rendus sont commités/poussés ; la promotion review → staging → prod suit l'ADR 0001 avec approbations obligatoires.
4. **Reconciliation Flux** : FluxCD récupère la branche/commit, applique les Kustomization dans l'ordre des dépendances (sources communes puis overlays par environnement). Aucun `kubectl apply` manuel.

## Points de vigilance DRY

- Les décisions et exigences de promotion sont décrites dans `docs/adr/0001-gitops-bootstrap.md` : ce document ne les duplique pas, il les référence.
- Les cibles reproductibles (`make render`, `make deploy`, `nix run .#render`) sont la source d'autorité pour la génération ; ne pas introduire de commandes alternatives non versionnées.
