# External Secrets Operator + OpenBao (GitOps)

External Secrets Operator est géré par FluxCD : HelmRelease, SecretStore et
ExternalSecret se trouvent dans `clusters/base/apps/external-secrets`.

Flux applique la configuration depuis `clusters/<env>` ; utiliser `make render ENV=review`
pour prévisualiser le manifest et pousser les changements pour déployer.

Les secrets doivent être chiffrés (SOPS/age ou SealedSecrets) avant d'être ajoutés au dépôt.

Pour tester en local ou partager un exemple autoportant, les manifestes suivants sont
disponibles dans ce répertoire (hors arborescence Flux) :

- `secretstore-openbao.yaml` : référence le cluster Vault OpenBao
  (`openbao.openbao.svc.cluster.local:8200`) via le backend KV v2 monté sur `kv`.
- `externalsecret-example.yaml` : synchronise un secret `demo-app-secret` dans le
  namespace `infra` en lisant les champs `username` et `password` depuis
  `kv/data/demo-app`.
