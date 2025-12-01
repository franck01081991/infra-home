# ADR 0001 – GitOps FluxCD + approbations review → staging → prod

## Contexte

L'infra k3s + OpenBao/ESO était déployée via scripts manuels. Objectif : sécuriser
les déploiements, tracer les changements et aligner tous les environnements via GitOps.

## Décision

- FluxCD comme contrôleur GitOps, Kustomization par environnement (`clusters/review|staging|prod`).
- Sources déclarées dans `clusters/base/sources/*` (GitRepository, HelmRepositories).
- OpenBao et External Secrets gérés via HelmRelease Flux + valeurs versionnées.
- Promotion séquentielle review → staging → prod, orchestrée par environnements GitHub Actions
  nécessitant approbation humaine avant déploiement.
- Manifests rendus localement (`make render` / `nix run .#render`) puis commit/push ; plus
  de `kubectl apply` manuel.
- Secrets chiffrés avec SOPS+age (ou SealedSecrets) avant d'entrer dans le dépôt.

## Conséquences

- CI enrichie (pre-commit, kubeconform, helm lint, sécurité) pour éviter de casser Flux.
- Les anciens scripts de déploiement direct sont remplacés par des cibles Make/Nix.
- La bootstrap OpenBao (unseal, root token) reste manuelle mais hors pipeline régulier.
- Les environnements GitHub doivent être configurés avec des règles d'approbation.
