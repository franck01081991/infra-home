# External Secrets Operator + OpenBao (GitOps)

External Secrets Operator est géré par FluxCD : HelmRelease, SecretStore et
ExternalSecret se trouvent dans `clusters/base/apps/external-secrets`.

Flux applique la configuration depuis `clusters/<env>` ; utiliser `make render ENV=review`
pour prévisualiser le manifest et pousser les changements pour déployer.

Les secrets doivent être chiffrés (SOPS/age ou SealedSecrets) avant d'être ajoutés au dépôt.
