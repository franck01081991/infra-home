#!/usr/bin/env bash
set -euo pipefail

for p in phone-01 phone-02 phone-03; do
  echo "[+] Building bundle for $p"
  nix build ".#$p"
  echo "    -> bundle for $p is in ./result (renommer ou déplacer avant le prochain build)"
done
