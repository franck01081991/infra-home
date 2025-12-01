#!/usr/bin/env bash

set -euo pipefail

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing dependency: $1" >&2
    exit 1
  fi
}

require nix

separator() {
  printf '%.0s-' {1..60}
  echo
}

addresses() {
  local host="$1"
  local iface="$2"

  # shellcheck disable=SC2016,SC2154
  nix eval --raw ".#nixosConfigurations.${host}.config.networking.interfaces.\"${iface}\".ipv4.addresses" \
    --apply 'addrs: builtins.concatStringsSep "\n" (map (a: "${a.address}/${builtins.toString a.prefixLength}") addrs)'
}

expect_address() {
  local host="$1"
  local iface="$2"
  local expected="$3"

  local got
  got=$(addresses "$host" "$iface")

  if [[ "$got" != *"$expected"* ]]; then
    echo "${host}:${iface} missing ${expected}" >&2
    echo "Found addresses:" >&2
    echo "$got" >&2
    exit 1
  fi
}

expect_master_flag() {
  local flag="$1"

  local flags
  flags=$(nix eval --raw '.#nixosConfigurations.rpi4-1.config.services.k3s.extraFlags')

  if [[ "$flags" != *"$flag"* ]]; then
    echo "k3s missing flag ${flag}" >&2
    echo "Current flags:" >&2
    echo "$flags" >&2
    exit 1
  fi
}

separator
echo "Checking VLAN/node addressing..."

expect_address rpi4-1 "eth0.10" "10.10.0.10/24"
expect_address rpi4-1 "eth0.10" "10.10.0.1/24"
expect_address rpi4-2 "eth0.10" "10.10.0.11/24"
expect_address rpi3a-ctl "wlan0" "10.10.0.12/24"

separator
echo "Checking k3s master/node IP flags..."
expect_master_flag "--node-ip=10.10.0.10"
expect_master_flag "--tls-san=10.10.0.10"

separator
echo "Checking default gateways..."
expect_gateway() {
  local host="$1"
  local expected="$2"

  local gateway
  # shellcheck disable=SC2016
  gateway=$(nix eval --raw ".#nixosConfigurations.${host}.config.networking.defaultGateway" \
    --apply 'gw: if builtins.isAttrs gw then gw.address else gw')

  if [[ "$gateway" != "$expected" ]]; then
    echo "${host} gateway mismatch: expected ${expected}, got ${gateway}" >&2
    exit 1
  fi
}

expect_gateway rpi4-1 "10.10.0.1"
expect_gateway rpi4-2 "10.10.0.1"
expect_gateway rpi3a-ctl "10.10.0.1"

echo "Addressing coherence OK"
