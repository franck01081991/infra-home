# OpenBao dans k3s (GitOps)

OpenBao est géré par FluxCD via le HelmRelease dans `clusters/base/apps/openbao`.
Les valeurs sont stockées dans `clusters/base/apps/openbao/values.yaml` et projetées
par un ConfigMap. Pour appliquer une modification :

1. Éditer le fichier de valeurs ou le HelmRelease.
2. `make render ENV=review` puis commit/push pour déclencher Flux.
3. Laisser la promotion review → staging → prod suivre les approbations.

Le script `k8s/openbao/bootstrap-openbao.sh` reste pour l'initialisation unique
(unseal + root token) après l'installation par Flux.
