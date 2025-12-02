# QUICKSTART

## Prérequis
- Nix installé avec flakes activés.
- Accès SSH aux hôtes (clé installée côté routeur/workers).
- Clés age disponibles pour déchiffrer les artefacts SOPS.
- Accès GitHub/CI configuré pour pousser les manifest rendus.

## Environnement de développement
```bash
nix develop          # fournit kubectl, flux, helm, age, linters…
nix flake check      # valide modules, topologie, options
make test            # lint + kubeconform + scans secrets
```

## Déploiement NixOS d'un hôte
```bash
# Reconstruit et applique un hôte (local ou via SSH)
scripts/deploy-rpi.sh [--ssh] <hostname>

# Boucle sur rpi4-1, rpi4-2, rpi3a-ctl
scripts/deploy-all.sh [--ssh]
```
Remplacez `hosts/<hôte>/hardware-configuration.nix` par la sortie de `nixos-generate-config` exécutée sur la machine avant le déploiement.

## Pipeline GitOps k3s (FluxCD)
```bash
make render ENV=review   # génère dist/review.yaml
make deploy ENV=review   # render + rappel de push Git
nix run .#render -- --env staging
```
Les Kustomization Flux enchaînent `review → staging → prod` selon l'ADR 0001.

## Bootstrap OpenBao
1. Déployer les charts OpenBao/ESO via Flux (`clusters/base/apps`).
2. Déchiffrer les artefacts SOPS vers `/run/secrets/openbao/*` et `/run/secrets/eso/openbao-token`.
3. Exécuter `scripts/bootstrap-openbao.sh` (idempotent) pour unseal, policies et token ESO.
4. Committer/valider les `SecretStore` et `ExternalSecret` correspondants.
