#!/usr/bin/env bash
set -euo pipefail

HOSTS=(
  rpi4-1
  rpi4-2
  rpi3a-ctl
)

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--ssh]

Iterates over all Raspberry Pi hosts and calls deploy-rpi.sh.

Options:
  --ssh       Deploy over SSH (remote build + switch on target host).
  -h, --help  Show this help message.
USAGE
}

main() {
  local use_ssh="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ssh)
        use_ssh="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[ERROR] Unexpected argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  for host in "${HOSTS[@]}"; do
    echo "[INFO] Deploying ${host}"
    if [[ "$use_ssh" == "true" ]]; then
      ./scripts/deploy-rpi.sh --ssh "$host"
    else
      ./scripts/deploy-rpi.sh "$host"
    fi
  done
}

main "$@"
