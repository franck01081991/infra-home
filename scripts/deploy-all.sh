#!/usr/bin/env bash
set -euo pipefail

./scripts/deploy-rpi.sh rpi4-1
./scripts/deploy-rpi.sh rpi4-2
./scripts/deploy-rpi.sh rpi3a-ctl
