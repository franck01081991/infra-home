#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🧪 Exécution de la suite de tests infra-home..."
echo "=============================================="

# Exécuter les tests BATS
echo "📋 Exécution des tests BATS..."
if command -v bats >/dev/null 2>&1; then
    bats "$SCRIPT_DIR"/*.bats
    echo "✅ Tests BATS terminés"
else
    echo "⚠️  BATS non trouvé, tests bash ignorés"
fi

echo ""

# Exécuter les tests de configuration Nix (si nix est disponible)
echo "🔧 Exécution des tests de configuration Nix..."
if command -v nix >/dev/null 2>&1; then
    cd "$PROJECT_ROOT"
    nix-instantiate --eval --strict tests/test_nix_config.nix -A runTests
    echo "✅ Tests de configuration Nix terminés"
else
    echo "⚠️  Nix non trouvé, tests Nix ignorés"
fi

echo ""

# Exécuter les tests de validation existants
echo "🔍 Exécution des tests de validation existants..."
cd "$PROJECT_ROOT"

if command -v shellcheck >/dev/null 2>&1; then
    echo "  - Exécution de shellcheck..."
    make shellcheck
    echo "  ✅ Shellcheck réussi"
else
    echo "  ⚠️  Shellcheck non trouvé"
fi

echo ""
echo "🎉 Tous les tests disponibles terminés avec succès!"