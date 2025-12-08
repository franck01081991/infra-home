SHELL := bash
ENV ?= review
KUSTOMIZE ?= ./bin/kustomize

.PHONY: test unit-tests pre-commit nix-check shellcheck kubeconform helm-lint render deploy tools kustomize
.PHONY: security-scan kube-lint nix-lint trivy-scan full-test format-nix install-tools

# Test complet avec tous les outils de qualité
test: unit-tests pre-commit nix-check shellcheck kubeconform helm-lint

# Test complet incluant les scans de sécurité
full-test: test security-scan

# Tous les scans de sécurité
security-scan: kube-lint trivy-scan nix-lint

unit-tests:
	./tests/run_tests.sh

pre-commit:
	pre-commit run --all-files

nix-check:
	nix flake check --all-systems

shellcheck:
	find scripts -name '*.sh' -print0 | xargs -0 -r shellcheck
	find k8s -name '*.sh' -print0 | xargs -0 -r shellcheck

kubeconform:
	for env in review staging prod; do \
		$(KUSTOMIZE) build clusters/$$env | kubeconform -strict \
		  --skip CustomResourceDefinition,HelmRepository,HelmRelease,GitRepository,Kustomization,Application,SecretStore,ExternalSecret \
		  --summary; \
	done

helm-lint:
	helm repo add openbao https://openbao.github.io/openbao-helm
	helm repo add external-secrets https://charts.external-secrets.io
	helm pull openbao/openbao --untar --untardir /tmp/openbao-chart
	helm lint /tmp/openbao-chart/openbao -f clusters/base/apps/openbao/values.yaml

render:
	./scripts/render-desired-state.sh $(ENV)

# Linting Kubernetes avec kube-linter
kube-lint:
	@echo "🔍 Analyse des manifestes Kubernetes avec kube-linter..."
	@if ! command -v kube-linter >/dev/null 2>&1; then \
		echo "❌ kube-linter non installé. Utilisez 'make install-tools'"; \
		exit 1; \
	fi
	@for env in review staging prod; do \
		echo "Analysing $$env environment..."; \
		$(KUSTOMIZE) build clusters/$$env > /tmp/manifests-$$env.yaml; \
		kube-linter lint /tmp/manifests-$$env.yaml --config .kube-linter.yaml || true; \
	done

# Scan de sécurité avec Trivy
trivy-scan:
	@echo "🔍 Scan de sécurité avec Trivy..."
	@if ! command -v trivy >/dev/null 2>&1; then \
		echo "❌ trivy non installé. Utilisez 'make install-tools'"; \
		exit 1; \
	fi
	@echo "Scanning repository..."
	trivy fs --severity HIGH,CRITICAL . || true
	@if [ -f "Dockerfile" ]; then \
		echo "Scanning Dockerfile..."; \
		trivy config --severity HIGH,CRITICAL Dockerfile || true; \
	fi

# Linting Nix avec nixpkgs-lint
nix-lint:
	@echo "🔍 Analyse du code Nix avec nixpkgs-lint..."
	@if ! command -v nixpkgs-lint >/dev/null 2>&1; then \
		echo "❌ nixpkgs-lint non installé. Installez avec 'nix profile install nixpkgs#nixpkgs-lint'"; \
		exit 1; \
	fi
	@nixpkgs-lint . || true

# Formatage automatique du code Nix
format-nix:
	@echo "🎨 Formatage du code Nix..."
	find . -name "*.nix" -type f -exec nix fmt {} \;

# Installation des outils de développement
install-tools: kustomize
	@echo "🛠️  Installation des outils de développement..."
	@echo "Installing kube-linter..."
	@if ! command -v kube-linter >/dev/null 2>&1; then \
		curl -L "https://github.com/stackrox/kube-linter/releases/download/0.6.8/kube-linter-linux.tar.gz" | tar -xz; \
		sudo mv kube-linter /usr/local/bin/; \
	fi
	@echo "Installing trivy..."
	@if ! command -v trivy >/dev/null 2>&1; then \
		curl -L "https://github.com/aquasecurity/trivy/releases/download/v0.55.2/trivy_0.55.2_Linux-64bit.tar.gz" | tar -xz; \
		sudo mv trivy /usr/local/bin/; \
	fi
	@echo "✅ Outils installés avec succès!"

# Créer la configuration kube-linter si elle n'existe pas
.kube-linter.yaml:
	@echo "📝 Création de la configuration kube-linter..."
	@cat > .kube-linter.yaml << 'EOF'
	checks:
	  doNotAutoAddDefaults: false
	  exclude:
	    - "no-read-only-root-fs"
	    - "run-as-non-root"
	    - "required-label-owner"
	  include:
	    - "no-privileged-containers"
	    - "no-host-network"
	    - "no-host-pid"
	    - "no-host-ipc"
	    - "cpu-requirements"
	    - "memory-requirements"
	    - "security-context-non-root"
	EOF

deploy: render
	@echo "Manifest généré dans dist/$(ENV).yaml ; commit/push pour déclencher Flux (review→staging→prod)."

tools: kustomize

kustomize:
	./scripts/install-kustomize.sh

# Aide pour afficher les commandes disponibles
help:
	@echo "🚀 Commandes disponibles pour infra-home:"
	@echo ""
	@echo "  📋 Tests et validation:"
	@echo "    make test           - Tests de base (unit, lint, nix-check)"
	@echo "    make full-test      - Tests complets avec scans de sécurité"
	@echo "    make security-scan  - Scans de sécurité uniquement"
	@echo ""
	@echo "  🔍 Outils spécifiques:"
	@echo "    make shellcheck     - Vérification des scripts bash"
	@echo "    make kubeconform    - Validation des manifestes Kubernetes"
	@echo "    make kube-lint      - Analyse de sécurité Kubernetes"
	@echo "    make trivy-scan     - Scan de vulnérabilités"
	@echo "    make nix-lint       - Analyse du code Nix"
	@echo ""
	@echo "  🎨 Formatage:"
	@echo "    make format-nix     - Formater le code Nix"
	@echo ""
	@echo "  🚀 Déploiement:"
	@echo "    make render ENV=review  - Générer les manifestes"
	@echo "    make deploy ENV=review  - Déployer (review/staging/prod)"
	@echo ""
	@echo "  🛠️  Installation:"
	@echo "    make install-tools  - Installer les outils de développement"
	@echo "    make tools          - Installer kustomize"
	@echo ""
	@echo "  💡 Variables d'environnement:"
	@echo "    ENV=review|staging|prod  (défaut: review)"
