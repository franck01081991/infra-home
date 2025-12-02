# OpenBao dans k3s (GitOps)

OpenBao est géré par FluxCD via le HelmRelease dans `clusters/base/apps/openbao`.
Les valeurs de déploiement sont stockées dans `clusters/base/apps/openbao/values.yaml`
et projetées par un ConfigMap. Un fichier de référence local `k8s/openbao/values-openbao.yaml`
reprend la configuration attendue (stockage Raft + classe `local-path`, service
`openbao:8200`, sélection des nœuds `role=infra`) pour aligner les installations
manuelles avec le bootstrap.

Pour appliquer une modification :

1. Éditer le fichier de valeurs ou le HelmRelease.
2. `make render ENV=review` puis commit/push pour déclencher Flux.
3. Laisser la promotion review → staging → prod suivre les approbations.

Le script `k8s/openbao/bootstrap-openbao.sh` reste pour l'initialisation unique
(unseal + root token) après l'installation par Flux. Il cible **le pod stateful
`openbao-0`** (ordinal déterministe) et attend sa condition **Ready** avant
de lancer `bao operator init`, garantissant une initialisation reproductible.

Après l'init, capture la clé d'unseal et le root token puis stocke-les **uniquement**
dans un secret chiffré (ex: `secrets/openbao-bootstrap.enc.yaml` géré par
SOPS+age et projeté par Flux/Argo). Ne jamais committer ces valeurs en clair.
