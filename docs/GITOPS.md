# GITOPS

## Structure FluxCD
```
clusters/
  base/            # namespaces, sources Flux, HelmReleases OpenBao/ESO
  review/          # overlay + Kustomization review
  staging/         # dépend de review
  prod/            # dépend de staging
```
OpenBao et External Secrets Operator sont installés via `clusters/base/apps/*`. La promotion se fait par branches/revues Git conformément à l'ADR 0001.

## Commandes courantes
```bash
make render ENV=<env>
make deploy ENV=<env>
nix run .#render -- --env <env>
```
`kustomize build clusters/<env> | kubeconform ...` reste la validation locale recommandée (intégrée dans `make test`).

## k8s/ vs clusters/
- `clusters/` est la source officielle consommée par FluxCD.
- `k8s/` contient des manifestes legacy ou d'exemple (OpenBao/ESO) non appliqués par Flux ; conserver pour référence ou renommer en `k8s-legacy/` si besoin. Aucune CI ne doit déployer `k8s/` directement.

## CI/CD
- Workflow `.github/workflows/ci.yaml` : `nix flake check`, `yamllint --strict`, `kustomize build` + `kubeconform -strict`, `trufflehog` secrets.
- Prévoir tfsec/checkov, shellcheck, kube-linter, trivy via `make test`/pre-commit pour rester DRY.
- Environnements protégés `review → staging → prod` avec approbations Git avant synchronisation Flux.

## OpenBao + ESO
- OpenBao sert de coffre runtime ; ESO synchronise vers les Secrets k8s via `SecretStore`/`ExternalSecret`.
- Les tokens/artefacts de bootstrap sont chiffrés via SOPS/age et rendus en tmpfs (`/run/secrets/openbao/*`, `/run/secrets/eso/openbao-token`).
