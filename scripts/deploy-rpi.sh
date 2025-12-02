#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--ssh] <hostname>

Rebuilds and switches a single NixOS host using the flake in the current repo.

Options:
  --ssh       Deploy over SSH (remote build + switch on target host).
  -h, --help  Show this help message.

Examples:
  $(basename "$0") rpi4-1
  $(basename "$0") --ssh rpi3a-ctl
USAGE
}

main() {
  local use_ssh="false"
  local host

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
        if [[ -n ${host-} ]]; then
          echo "[ERROR] Unexpected argument: $1" >&2
          usage >&2
          exit 1
        fi
        host="$1"
        shift
        ;;
    esac
  done

  if [[ -z ${host-} ]]; then
    echo "[ERROR] Hostname is required." >&2
    usage >&2
    exit 1
  fi

  local flake_ref=".#${host}"
  local ssh_args=()

  if [[ "$use_ssh" == "true" ]]; then
    ssh_args+=("--target-host" "$host" "--build-host" "$host")
  fi

  echo "[INFO] Deploying ${host} (ssh=${use_ssh})"
  nixos-rebuild switch --flake "$flake_ref" "${ssh_args[@]}"
}

main "$@"
