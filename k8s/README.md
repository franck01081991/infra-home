# ⚠️ Répertoire Legacy - Ne pas utiliser

## 🚨 Important

Ce répertoire `k8s/` contient d'anciens manifestes Kubernetes qui ne sont **plus utilisés** dans le projet infra-home.

### ❌ Ce qui ne fonctionne plus

- Les manifestes dans ce répertoire ne sont **pas déployés** par la CI/CD
- Ils ne sont **pas synchronisés** par FluxCD
- Ils peuvent contenir des configurations **obsolètes**
- Ils ne suivent **pas** la structure GitOps actuelle

### ✅ Ce qu'il faut utiliser à la place

Utilisez le répertoire `clusters/` qui contient la configuration GitOps moderne :

```
clusters/
├── base/           # Configuration de base
├── review/         # Environnement de test
├── staging/        # Pré-production
└── prod/          # Production
```

### 🔄 Migration

Si vous trouvez quelque chose d'utile dans ce répertoire legacy :

1. **Ne modifiez pas** les fichiers ici
2. **Adaptez** la configuration dans `clusters/base/`
3. **Testez** avec `make render ENV=review`
4. **Déployez** via le processus GitOps normal

### 📚 Documentation

Pour déployer de nouvelles applications, consultez :
- [`docs/EXAMPLES.md`](../docs/EXAMPLES.md) - Exemples de déploiement
- [`docs/GITOPS.md`](../docs/GITOPS.md) - Processus GitOps
- [`docs/QUICKSTART.md`](../docs/QUICKSTART.md) - Guide de démarrage

---

> 💡 **Note** : Ce répertoire est conservé uniquement pour référence historique. Il sera supprimé dans une future version du projet.