# SECRETS

## Stratégie
- **SOPS + age** pour les artefacts versionnés (`secrets/*.enc.yaml`, `.age`) ; jamais de secrets en clair dans Git ou le store Nix.
- **OpenBao** pour les secrets runtime k8s ; synchronisation par External Secrets Operator.
- Règle : les modules Nix consomment uniquement des fichiers temporaires en `/run/secrets/*` (tmpfs).

## Chemins `/run/secrets/*`
- `/run/secrets/wpa_supplicant.env` : `WAN_4G_PSK`, `INFRA_K3S_PSK` pour le Wi-Fi routeur/workers.
- `/run/secrets/k3s/token` : token serveur k3s.
- `/run/secrets/openbao/root-token`, `/run/secrets/openbao/unseal-keys` : bootstrap OpenBao.
- `/run/secrets/eso/openbao-token` : token ESO pour `SecretStore`.

## Workflow recommandé
1. Générer/maintenir les clés age et `.sops.yaml` (recipients).
2. Chiffrer les artefacts (PSK, tokens k3s/ESO/OpenBao) dans `secrets/*.enc.yaml` via `sops -e`.
3. CI ou machine cible déchiffre vers `/run/secrets/*` en tmpfs (LoadCredential ou sops-nix), jamais sur disque persistant.
4. Déployer OpenBao, exécuter `scripts/bootstrap-openbao.sh`, puis laisser ESO synchroniser les secrets applicatifs.

## Bonnes pratiques
- Rotation régulière des tokens/PSK, commit des artefacts chiffrés uniquement.
- Pas de secrets dans les options Nix, manifests Kustomize ou logs CI.
- Vérifier `make test`/`trufflehog` avant toute PR.
