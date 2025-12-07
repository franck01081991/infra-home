# Tests

Ce répertoire contient les tests unitaires pour le projet infra-home.

## Structure des Tests

### Tests BATS (Bash Automated Testing System)

- **`test_topology.bats`** : Tests pour la configuration de topologie Nix
  - Validation de la configuration VLAN (IDs uniques, sous-réseaux valides)
  - Vérification de la cohérence de la configuration cluster
  - Validation de la complétude de la configuration des hôtes
  - Tests de la logique de configuration routeur

- **`test_check_addressing.bats`** : Tests pour les fonctions des scripts bash
  - Tests des fonctions utilitaires de `scripts/check-addressing.sh`
  - Validation de la logique de vérification d'adresses
  - Tests de validation des flags de cluster
  - Tests de validation de la configuration des passerelles

### Tests Nix

- **`test_nix_config.nix`** : Tests de validation de configuration basés sur Nix
  - Validation type-safe de la configuration de topologie
  - Vérifications de cohérence entre différentes sections de configuration
  - Nécessite Nix pour être exécuté

## Exécution des Tests

### Exécuter Tous les Tests
```bash
make unit-tests
# ou
./tests/run_tests.sh
```

### Exécuter des Suites Spécifiques

#### Tests BATS Uniquement
```bash
bats tests/*.bats
```

#### Fichiers de Tests Individuels
```bash
bats tests/test_topology.bats
bats tests/test_check_addressing.bats
```

#### Tests Nix Uniquement (nécessite Nix)
```bash
nix-instantiate --eval --strict tests/test_nix_config.nix -A runTests
```

## Couverture des Tests

Les tests couvrent :

1. **Validation de Configuration**
   - Cohérence de la topologie VLAN
   - Validation de l'adressage réseau
   - Configuration du cluster (k3s/RKE2)
   - Complétude de la configuration des hôtes

2. **Tests de Fonctions de Scripts**
   - Fonctions utilitaires bash
   - Logique de validation d'adresses
   - Gestion d'erreurs et rapports

3. **Tests d'Intégration**
   - Cohérence de configuration entre composants
   - Validation de la topologie réseau
   - Validation de la configuration cluster

## Dépendances

- **bats** : Pour les tests de scripts bash
- **shellcheck** : Pour le linting des scripts shell (déjà dans Makefile)
- **nix** : Pour les tests de configuration Nix (optionnel)

Installation de BATS sur Debian/Ubuntu :
```bash
apt install bats
```

## Ajout de Nouveaux Tests

### Pour les Scripts Bash
1. Créer ou étendre les fichiers `.bats` dans ce répertoire
2. Suivre les conventions de test BATS
3. Tester les fonctions individuelles en sourçant les scripts
4. Utiliser des mocks pour les dépendances externes (comme `nix eval`)

### Pour la Configuration Nix
1. Ajouter des fonctions de test à `test_nix_config.nix`
2. Utiliser le système d'assertion de Nix pour la validation
3. S'assurer que les tests sont purs et ne dépendent pas d'un état externe

### Bonnes Pratiques
- Tester les cas de succès et d'échec
- Utiliser des noms de tests descriptifs
- Mocker les dépendances externes
- Garder les tests rapides et isolés
- Documenter la logique de test complexe

## Évolution Future

### Support RKE2
Les tests sont conçus pour être facilement adaptés lors de la migration de k3s vers RKE2 :
- Configuration cluster abstraite dans la topologie
- Tests de validation génériques pour les clusters Kubernetes
- Séparation entre logique réseau et logique cluster

### Support Architectures x86
La structure de tests supporte l'ajout de machines x86 :
- Tests de topologie indépendants de l'architecture
- Validation de configuration par type de machine
- Tests d'adressage réseau génériques