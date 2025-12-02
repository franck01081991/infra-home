# Gestion des secrets

- Chiffrer tout secret applicatif avec **SOPS + age** (ou SealedSecrets) avant commit.
- Stocker les clés age hors dépôt (ex : stockage chiffré du pipeline).
- Préfixer les fichiers secrets par `*.enc.yaml` et les référencer via ExternalSecrets.
- Utiliser les modèles dans `secrets/templates/*.enc.yaml` comme base, puis les chiffrer via `sops -e` avant toute utilisation.
- Ne jamais commiter de tokens en clair ni afficher les valeurs dans les logs CI.

## Fichier `/run/secrets/wpa_supplicant.env`

- Généré et déchiffré au runtime (ex : sops-nix) à partir d'un secret chiffré **SOPS/age**.
- Format attendu : variables d'environnement consommées par `networking.wireless.secretsFile`.

```env
# PSK de l'AP cellulaire
WAN_4G_PSK="wpa2-psk-chiffree"

# PSK du réseau INFRA-K3S
INFRA_K3S_PSK="wpa2-psk-chiffree"
```

- Le fichier ne doit jamais être commité en clair. Il est monté en `/run/secrets/wpa_supplicant.env` via la CI/CD ou un drop-in systemd.
