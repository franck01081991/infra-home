# 🔧 Guide de dépannage du pipeline CI

## 📋 **Problèmes résolus récemment**

### **1. Erreur "not in gzip format" avec kustomize**

**🚨 Symptôme :**
```
gzip: stdin: not in gzip format
tar: Child returned status 1
tar: Error is not recoverable: exiting now
Process completed with exit code 2.
```

**🔍 Cause :**
L'URL de téléchargement de kustomize était incorrecte. Le pipeline construisait :
```
https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v5.3.0/kustomize_v5.3.0_linux_amd64.tar.gz
```

Mais l'URL correcte est :
```
https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.3.0/kustomize_v5.3.0_linux_amd64.tar.gz
```

**✅ Solution appliquée :**
```yaml
# AVANT (incorrect)
KUSTOMIZE_BASE="https://github.com/kubernetes-sigs/kustomize/releases"
KUSTOMIZE_URL="${KUSTOMIZE_BASE}/download/kustomize/v${KUSTOMIZE_VERSION}/"
KUSTOMIZE_URL+="kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"

# APRÈS (correct)
KUSTOMIZE_URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
```

### **2. Erreur "not in gzip format" avec kube-linter**

**🚨 Symptôme :**
```
gzip: stdin: not in gzip format
tar: Child returned status 1
tar: Error is not recoverable: exiting now
```

**🔍 Cause :**
L'URL de téléchargement de kube-linter était incorrecte. Il manquait le préfixe "v" devant la version :
```
# INCORRECT
https://github.com/stackrox/kube-linter/releases/download/0.7.6/kube-linter-linux.tar.gz

# CORRECT
https://github.com/stackrox/kube-linter/releases/download/v0.7.6/kube-linter-linux.tar.gz
```

**✅ Solution appliquée :**
```yaml
# AVANT (incorrect)
KUBE_LINTER_URL="https://github.com/stackrox/kube-linter/releases"
KUBE_LINTER_URL+="/download/${KUBE_LINTER_VERSION}/"
KUBE_LINTER_URL+="kube-linter-linux.tar.gz"

# APRÈS (correct)
KUBE_LINTER_URL="https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/kube-linter-linux.tar.gz"
```

### **3. Problème de formatage Nix**

**🚨 Symptôme :**
```
❌ ./nix/devshell.nix is not properly formatted. Run 'nix fmt ./nix/devshell.nix' to fix it.
```

**🔍 Cause :**
Le fichier Nix n'était pas formaté selon le standard RFC attendu par le pipeline CI.

**✅ Solution :**

- Vérifier que `nix/devshell.nix` existe et reste formaté.
- Lancer `nix fmt ./flake.nix` et `nix fmt ./nix/devshell.nix`.

### **4. Erreur "check not found" avec kube-linter**

**🚨 Symptôme :**
```
Error: enabled checks validation errors: [check "no-host-network" not found, check "cpu-requirements" not found, ...]
```

**🔍 Cause :**
Les noms des checks utilisés dans la configuration ne correspondent pas à ceux disponibles dans kube-linter 0.7.6.

**✅ Solution :**
```yaml
# AVANT (checks inexistants)
checks:
  include:
    - "no-privileged-containers"
    - "no-host-network"
    - "cpu-requirements"

# APRÈS (utiliser les checks par défaut avec exclusions)
checks:
  doNotAutoAddDefaults: false
  exclude:
    - "no-read-only-root-fs"
    - "run-as-non-root"
    - "required-label-owner"
    - "privileged"
```

## 🛠️ **Comment diagnostiquer les problèmes CI**

### **Étape 1 : Identifier le job qui échoue**
1. Allez sur GitHub dans l'onglet "Actions"
2. Cliquez sur le pipeline qui a échoué
3. Identifiez le job en rouge (par exemple "validate-k8s-manifests")

### **Étape 2 : Analyser les logs d'erreur**
1. Cliquez sur le job qui a échoué
2. Dépliez les étapes pour voir les détails
3. Cherchez les messages d'erreur en rouge

### **Étape 3 : Types d'erreurs courantes**

#### **Erreurs de téléchargement**
- **Symptômes :** "not in gzip format", "404 Not Found", "curl failed"
- **Causes :** URL incorrecte, version inexistante, problème réseau
- **Solution :** Vérifier l'URL et la version dans les variables d'environnement

#### **Erreurs de formatage**
- **Symptômes :** "not properly formatted", "lint failed"
- **Causes :** Code non conforme aux standards
- **Solution :** Utiliser les outils de formatage (nixfmt, yamllint, etc.)

#### **Erreurs de validation**
- **Symptômes :** "validation failed", "schema error"
- **Causes :** Configuration Kubernetes invalide
- **Solution :** Vérifier la syntaxe YAML et les schémas K8s

## 🔧 **Outils de dépannage locaux**

### **Tester le formatage Nix**
```bash
# Installer nixfmt (si Nix est disponible)
nix-shell -p nixfmt-rfc-style

# Vérifier le formatage
find . -name "*.nix" -print0 | xargs -0 nixfmt --check

# Corriger automatiquement
find . -name "*.nix" -print0 | xargs -0 nixfmt
```

### **Tester la validation YAML**
```bash
# Installer yamllint
pip install yamllint

# Vérifier les fichiers YAML
yamllint .github/workflows/ci.yaml
```

### **Tester les URLs de téléchargement**
```bash
# Tester une URL avant de l'utiliser dans le CI
curl -I "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.3.0/kustomize_v5.3.0_linux_amd64.tar.gz"

# Doit retourner "200 OK" et "Content-Type: application/gzip"

# Tester kube-linter (attention au préfixe 'v')
curl -I "https://github.com/stackrox/kube-linter/releases/download/v0.7.6/kube-linter-linux.tar.gz"
```

### **Tester la configuration kube-linter**
```bash
# Lister les checks disponibles
kube-linter checks list

# Tester une configuration
kube-linter lint --config .kube-linter.yaml manifest.yaml
```

## 📚 **Bonnes pratiques pour éviter les problèmes**

### **1. Vérification des URLs**
- Toujours tester les URLs de téléchargement manuellement
- Utiliser des versions stables et documentées
- Vérifier que les fichiers existent avant de les utiliser dans le CI

### **2. Formatage du code**
- Utiliser les outils de formatage automatique
- Configurer des hooks pre-commit pour le formatage
- Tester localement avant de pousser

### **3. Validation des configurations**
- Utiliser des outils de validation (kubeconform, yamllint)
- Tester les manifests Kubernetes localement
- Vérifier la syntaxe avant de commiter

### **4. Gestion des versions**
- Utiliser des versions spécifiques plutôt que "latest"
- Documenter les versions utilisées
- Tester les mises à jour de versions séparément

## 🚨 **Que faire en cas de problème**

1. **Ne pas paniquer** - Les erreurs CI sont normales et réparables
2. **Lire attentivement** les messages d'erreur
3. **Identifier la cause** (téléchargement, formatage, validation)
4. **Tester localement** si possible
5. **Faire des corrections ciblées** plutôt que des changements massifs
6. **Commiter et pousser** les corrections
7. **Vérifier** que le pipeline passe

## 📞 **Ressources d'aide**

- **Documentation Nix :** https://nixos.org/manual/nix/stable/
- **Documentation Kubernetes :** https://kubernetes.io/docs/
- **GitHub Actions :** https://docs.github.com/en/actions
- **Kustomize releases :** https://github.com/kubernetes-sigs/kustomize/releases

---

💡 **Conseil :** Gardez ce guide à portée de main pour diagnostiquer rapidement les problèmes CI futurs !