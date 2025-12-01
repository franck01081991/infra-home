# Phone bundles (k3s agents)

## K3S token delivery (no secret in Git/Nix store)
- Stocker le token chiffré via **SOPS + age** hors Nix store (ex: `secrets/k3s-token.enc.yaml`).
- Déchiffrer le token à l'exécution (CI/CD ou provisionnement) vers un fichier volatile, par exemple `/run/secrets/k3s/token`, avec permissions strictes (600) :
  ```bash
  sops -d secrets/k3s-token.enc.yaml > /run/secrets/k3s/token
  chmod 600 /run/secrets/k3s/token
  ```
- Lancer l'agent en pointant vers ce fichier (valeur lue sans être copiée dans le store) :
  ```bash
  K3S_TOKEN_FILE=/run/secrets/k3s/token ./start-k3s-agent
  ```
- En alternative, exporter `K3S_TOKEN` dans l'environnement _sans_ l'écrire sur disque et avant d'exécuter `start-k3s-agent`.

## Build
Utiliser le script `scripts/build-phones.sh` pour générer les bundles Nix (idempotent). Les secrets restent fournis au runtime uniquement.
