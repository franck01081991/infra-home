#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"

if [ -z "$HOST" ]; then
  echo "Usage: $0 <hostname>" >&2
  exit 1
fi

echo "[+] Deploying $HOST"
sudo nixos-rebuild switch --flake ".#$HOST"
