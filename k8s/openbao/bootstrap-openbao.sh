#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="openbao"
STATEFULSET="openbao"
POD="${STATEFULSET}-0"

if ! kubectl get pod -n "$NAMESPACE" "$POD" >/dev/null 2>&1; then
  echo "[-] ${POD} introuvable dans le namespace ${NAMESPACE}."
  exit 1
fi

echo "[+] Attente du pod ${POD} (condition Ready)..."
kubectl wait --namespace "$NAMESPACE" --for=condition=Ready pod "$POD" --timeout=120s

echo "[+] Initialisation OpenBao dans le pod: $POD"
kubectl exec -n "$NAMESPACE" -ti "$POD" -- \
  bao operator init -key-shares=1 -key-threshold=1

cat <<'EOF'
[!] Stocke la clé d'unseal et le root token dans un secret chiffré (ex: SOPS+age)
    sans jamais les committer en clair. Pense à référencer l'artefact chiffré
    dans un composant GitOps (Flux/Argo) pour automatiser la restauration.
EOF
