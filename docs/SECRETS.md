# Gouvernance des secrets (SOPS/age vs OpenBao)

Ce document détaille la responsabilité de chaque composant de gestion des secrets
(SOPS/age côté Git, OpenBao côté cluster), les chemins attendus dans `/run/secrets/*`,
le fonctionnement d'External Secrets Operator (ESO) avec `SecretStore`, ainsi que
les procédures de bootstrap GitOps-first.

## Périmètre et responsabilités

| Composant | Rôle | Emplacement / scope | Mode d'accès | Notes |
| --- | --- | --- | --- | --- |
| **SOPS + age** | Chiffrer les artefacts persistants versionnés (tokens k3s, PSK Wi-Fi, tokens d'init OpenBao/ESO) | Répertoire `secrets/` du dépôt, fichiers `*.enc.yaml` ou `.age` | Déchiffrement côté CI/CD ou node via clé age privée injectée en secret | Jamais de secret en clair dans Git ; les fichiers sont rendus vers `/run/secrets/*` en tmpfs au runtime |
| **OpenBao** | Coffre runtime pour secrets dynamiques (certificats, mots de passe applicatifs, creds DB, PKI) | Namespace `security` dans le cluster k3s, pod `openbao-<n>` | API TLS (ClusterIP) et injection par ESO via `SecretStore` | Stocke les secrets applicatifs et dynamiques ; le root/unseal token est géré par SOPS/age |
| **External Secrets Operator (ESO)** | Synchronisation OpenBao → Kubernetes Secrets | Ressources `SecretStore` (cluster-scoped) et `ExternalSecret` (namespaced) dans `clusters/base/apps/external-secrets` | Lit OpenBao via un rôle dédié (token, approle, JWT) | Les manifests restent déclaratifs et sans secret en clair |

## Chemins `/run/secrets/*`

Les modules et scripts consomment uniquement des secrets matérialisés en tmpfs pour
éviter toute fuite dans le store Nix ou les logs :

- `/run/secrets/wpa_supplicant.env` : PSK Wi-Fi (WAN_4G_PSK, INFRA_K3S_PSK) attendu par `networking.wireless.secretsFile` et le module `wireless-secrets-compat.nix`.
- `/run/secrets/k3s/token` : token serveur k3s injecté par un module `LoadCredential` ou `sops-nix`.
- `/run/secrets/openbao/root-token` et `/run/secrets/openbao/unseal-keys` : secrets de bootstrap OpenBao (jamais committés en clair), utilisés uniquement pendant l'init/unseal.
- `/run/secrets/eso/openbao-token` : token applicatif dédié à ESO pour lire les secrets OpenBao via `SecretStore`.

Chaque fichier est généré à partir d'un artefact chiffré `secrets/*.enc.yaml` (SOPS)
ou `.age` et doit être effacé/roté via la CI/CD ; aucune copie persistante sur disque.

## ESO et SecretStore

- La ressource `SecretStore` pointe vers OpenBao (adresse interne `http(s)://openbao.security.svc:8200`).
- L'authentification recommandée est basée sur **token** applicatif scellé dans `secrets/eso-openbao-token.enc.yaml` et monté en `/run/secrets/eso/openbao-token` par Flux/Argo.
- Les `ExternalSecret` référencent le `SecretStore` cluster-scoped (`spec.secretStoreRef.kind: ClusterSecretStore`) et les chemins OpenBao (`data[].remoteRef.key`).
- Les secrets k8s générés sont de type `Opaque` et restent éphémères ; la source d'autorité reste OpenBao.

## Bootstrap GitOps-first

### Clés age et artefacts SOPS

1. Générer une clé age (hors dépôt) : `age-keygen -o ~/.config/sops/age/keys.txt`.
2. Documenter l'empreinte publique dans un coffre hors Git (ex: password manager d'équipe).
3. Créer ou mettre à jour `.sops.yaml` pour référencer les `age` recipients.
4. Chiffrer les artefacts de bootstrap (PSK Wi-Fi, token k3s, token ESO, root/unseal OpenBao) en `secrets/*.enc.yaml` via `sops -e` ; ne jamais laisser le fichier déchiffré sur disque.
5. La CI/CD récupère la clé age privée depuis un secret pipeline et rend les fichiers chiffrés vers `/run/secrets/*`.

### OpenBao

1. Déployer le chart Helm OpenBao via Flux (`clusters/base/apps/openbao`).
2. Une fois le pod `openbao-0` prêt, déchiffrer les artefacts SOPS de bootstrap vers `/run/secrets/openbao/*`.
3. Exécuter `scripts/bootstrap-openbao.sh` (idempotent) pour :
   - réaliser l'unseal initial (utilise `/run/secrets/openbao/unseal-keys`),
   - configurer les policies/roles pour ESO (lecture sur les chemins applicatifs),
   - générer et stocker le token ESO dans `/run/secrets/eso/openbao-token` (également chiffré via SOPS).
4. Committer les manifests `SecretStore`/`ExternalSecret` pointant vers OpenBao ; Flux appliquera la synchro.

### External Secrets Operator

1. Déployer ESO via Flux (`clusters/base/apps/external-secrets`).
2. Appliquer/valider le `SecretStore` OpenBao (cluster-scoped) référencé par les `ExternalSecret` applicatifs.
3. Vérifier la conformation Kustomize/kubeconform (`make test`) et l'absence de secrets en clair.

## Modèles SOPS (non chiffrés, à chiffrer avant usage)

Des modèles prêts à l'emploi sont disponibles dans `secrets/templates/` pour standardiser les artefacts à chiffrer :

- `secrets/templates/wpa_supplicant.env.enc.yaml` : PSK Wi-Fi, exporté ensuite vers `/run/secrets/wpa_supplicant.env`.
- `secrets/templates/eso-openbao-token.enc.yaml` : token ESO pour le `SecretStore` OpenBao.
- `secrets/templates/openbao-root-unseal.enc.yaml` : root token et clés d'unseal OpenBao.

**Important :** ces fichiers ne sont pas chiffrés et ne contiennent que des placeholders ;
ils doivent être chiffrés avec SOPS/age avant tout commit ou déploiement effectif.
