#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="openbao"
POD=$(kubectl get pod -n "$NAMESPACE" -l "app.kubernetes.io/name=openbao" -o jsonpath='{.items[0].metadata.name}')

echo "[+] Initializing OpenBao in pod: $POD"
kubectl exec -n "$NAMESPACE" -ti "$POD" -- \
  bao operator init -key-shares=1 -key-threshold=1
