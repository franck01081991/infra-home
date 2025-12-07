SHELL := bash
ENV ?= review
KUSTOMIZE ?= ./bin/kustomize

.PHONY: test unit-tests pre-commit nix-check shellcheck kubeconform helm-lint render deploy tools kustomize

test: unit-tests pre-commit nix-check shellcheck kubeconform helm-lint

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

deploy: render
	@echo "Manifest généré dans dist/$(ENV).yaml ; commit/push pour déclencher Flux (review→staging→prod)."
tools: kustomize

kustomize:
	./scripts/install-kustomize.sh
