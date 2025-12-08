#!/bin/bash
# Script d'entrée pour l'environnement Docker infra-home

set -e

echo "🚀 Initialisation de l'environnement infra-home..."

# Vérifier si nous sommes dans un répertoire infra-home
if [ ! -f "flake.nix" ]; then
    echo "❌ Erreur : Ce conteneur doit être lancé depuis le répertoire infra-home"
    echo "💡 Utilisez : docker run -v \$(pwd):/workspace infra-home"
    exit 1
fi

# Configuration Git si des variables d'environnement sont fournies
if [ -n "$GIT_USER_NAME" ]; then
    git config --global user.name "$GIT_USER_NAME"
    echo "✅ Git user.name configuré : $GIT_USER_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
    echo "✅ Git user.email configuré : $GIT_USER_EMAIL"
fi

# Copier les clés SSH si elles sont montées
if [ -d "/ssh-keys" ]; then
    echo "🔑 Configuration des clés SSH..."
    cp -r /ssh-keys/* /home/nixuser/.ssh/ 2>/dev/null || true
    chmod 700 /home/nixuser/.ssh
    chmod 600 /home/nixuser/.ssh/* 2>/dev/null || true
    echo "✅ Clés SSH configurées"
fi

# Vérifier la connectivité réseau
echo "🌐 Vérification de la connectivité..."
if ping -c 1 google.com >/dev/null 2>&1; then
    echo "✅ Connectivité Internet OK"
else
    echo "⚠️  Pas de connectivité Internet détectée"
fi

# Entrer dans le shell de développement Nix
echo "📦 Chargement de l'environnement de développement Nix..."
echo "   Cela peut prendre quelques minutes lors du premier lancement..."

# Si aucune commande spécifique n'est fournie, entrer dans le devshell
if [ "$#" -eq 0 ] || [ "$1" = "/bin/bash" ]; then
    echo ""
    echo "🎯 Environnement prêt ! Vous pouvez maintenant utiliser :"
    echo "   • nix flake check      # Valider la configuration"
    echo "   • make test           # Lancer les tests"
    echo "   • make render ENV=review  # Générer les manifestes"
    echo "   • ./scripts/deploy-rpi.sh --help  # Aide déploiement"
    echo ""
    echo "📚 Consultez docs/QUICKSTART.md pour plus d'informations"
    echo ""

    # Entrer dans le devshell Nix
    exec nix develop --command bash
else
    # Exécuter la commande fournie dans le devshell
    exec nix develop --command "$@"
fi