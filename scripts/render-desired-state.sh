#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-${ENV:-review}}"
OUTPUT_DIR="dist"
OUTPUT_FILE="$OUTPUT_DIR/${ENV}.yaml"

if [[ ! -d "clusters/${ENV}" ]]; then
  echo "[!] Environnement '${ENV}' introuvable dans clusters/${ENV}" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "[+] Rendu Kustomize pour clusters/${ENV} → ${OUTPUT_FILE}"
kustomize build "clusters/${ENV}" >"${OUTPUT_FILE}"

echo "[+] Manifest rendu. Commit/push requis pour application par Flux (promotion review → staging → prod)."
