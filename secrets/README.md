# Gestion des secrets

- Chiffrer tout secret applicatif avec **SOPS + age** (ou SealedSecrets) avant commit.
- Stocker les clés age hors dépôt (ex : stockage chiffré du pipeline).
- Préfixer les fichiers secrets par `*.enc.yaml` et les référencer via ExternalSecrets.
- Ne jamais commiter de tokens en clair ni afficher les valeurs dans les logs CI.
