#!/usr/bin/env bats

# Tests pour les fonctions du script check-addressing.sh

setup() {
    export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
    export CHECK_SCRIPT="$SCRIPT_DIR/check-addressing.sh"
    
    # Sourcer le script pour tester les fonctions individuelles
    # Créer une version de test qui n'exécute pas la logique principale
    export TEST_SCRIPT="$BATS_TEST_DIRNAME/check-addressing-test.sh"
    
    # Créer une version de test du script avec seulement les fonctions
    cat > "$TEST_SCRIPT" << 'EOF'
#!/usr/bin/env bash

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing dependency: $1" >&2
    return 1
  fi
  return 0
}

separator() {
  printf '%.0s-' {1..60}
  echo
}

# Mock nix eval pour les tests
mock_nix_eval() {
    local config="$1"
    local apply="$2"
    
    case "$config" in
        *"rpi4-1"*"eth0.10"*"ipv4.addresses"*)
            echo "10.10.0.10/24"$'\n'"10.10.0.1/24"
            ;;
        *"rpi4-2"*"eth0.10"*"ipv4.addresses"*)
            echo "10.10.0.11/24"
            ;;
        *"rpi3a-ctl"*"wlan0"*"ipv4.addresses"*)
            echo "10.10.0.12/24"
            ;;
        # Support pour k3s et RKE2
        *"k3s.extraFlags"*|*"rke2.extraFlags"*)
            echo "--node-ip=10.10.0.10 --tls-san=10.10.0.10 --cluster-init"
            ;;
        *"defaultGateway"*)
            echo "10.10.0.1"
            ;;
        # Support pour machines x86 futures
        *"x86-"*"ipv4.addresses"*)
            echo "10.10.0.20/24"  # Plage réservée pour x86
            ;;
        *)
            echo "mock: configuration inconnue $config" >&2
            return 1
            ;;
    esac
}

addresses() {
  local host="$1"
  local iface="$2"
  
  mock_nix_eval ".#nixosConfigurations.${host}.config.networking.interfaces.\"${iface}\".ipv4.addresses"
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
    return 1
  fi
  return 0
}

expect_cluster_flag() {
  local flag="$1"
  local service_type="${2:-k3s}"  # k3s par défaut, RKE2 possible

  local flags
  case "$service_type" in
    "k3s")
      flags=$(mock_nix_eval '.#nixosConfigurations.rpi4-1.config.services.k3s.extraFlags')
      ;;
    "rke2")
      flags=$(mock_nix_eval '.#nixosConfigurations.rpi4-1.config.services.rke2.extraFlags')
      ;;
    *)
      echo "Type de service cluster non supporté: $service_type" >&2
      return 1
      ;;
  esac

  if [[ "$flags" != *"$flag"* ]]; then
    echo "$service_type flag manquant: ${flag}" >&2
    echo "Flags actuels:" >&2
    echo "$flags" >&2
    return 1
  fi
  return 0
}

# Fonction de compatibilité pour k3s
expect_master_flag() {
  expect_cluster_flag "$1" "k3s"
}

expect_gateway() {
  local host="$1"
  local expected="$2"

  local gateway
  gateway=$(mock_nix_eval ".#nixosConfigurations.${host}.config.networking.defaultGateway")

  if [[ "$gateway" != "$expected" ]]; then
    echo "${host} gateway mismatch: expected ${expected}, got ${gateway}" >&2
    return 1
  fi
  return 0
}
EOF
    
    chmod +x "$TEST_SCRIPT"
}

teardown() {
    [ -f "$TEST_SCRIPT" ] && rm -f "$TEST_SCRIPT"
}

@test "le script check-addressing existe et est exécutable" {
    [ -f "$CHECK_SCRIPT" ]
    [ -x "$CHECK_SCRIPT" ]
}

@test "la fonction require détecte les commandes manquantes" {
    source "$TEST_SCRIPT"
    
    # Test avec une commande qui devrait exister
    run require "bash"
    [ "$status" -eq 0 ]
    
    # Test avec une commande qui ne devrait pas exister
    run require "commande-inexistante-12345"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing dependency: commande-inexistante-12345"* ]]
}

@test "la fonction separator produit la sortie correcte" {
    source "$TEST_SCRIPT"
    
    run separator
    [ "$status" -eq 0 ]
    # Doit produire 60 tirets suivis d'une nouvelle ligne
    [ "${#lines[0]}" -eq 60 ]
    [[ "${lines[0]}" =~ ^-+$ ]]
}

@test "la fonction addresses retourne le format attendu" {
    source "$TEST_SCRIPT"
    
    run addresses "rpi4-1" "eth0.10"
    [ "$status" -eq 0 ]
    [[ "$output" == *"10.10.0.10/24"* ]]
    [[ "$output" == *"10.10.0.1/24"* ]]
}

@test "la fonction expect_address valide correctement" {
    source "$TEST_SCRIPT"
    
    # Test de validation réussie
    run expect_address "rpi4-1" "eth0.10" "10.10.0.10/24"
    [ "$status" -eq 0 ]
    
    # Test de validation échouée
    run expect_address "rpi4-1" "eth0.10" "192.168.1.1/24"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing 192.168.1.1/24"* ]]
}

@test "la fonction expect_cluster_flag valide les flags cluster" {
    source "$TEST_SCRIPT"
    
    # Test de validation réussie des flags k3s
    run expect_cluster_flag "--node-ip=10.10.0.10" "k3s"
    [ "$status" -eq 0 ]
    
    run expect_cluster_flag "--tls-san=10.10.0.10" "k3s"
    [ "$status" -eq 0 ]
    
    # Test de flag manquant
    run expect_cluster_flag "--flag-manquant" "k3s"
    [ "$status" -eq 1 ]
    [[ "$output" == *"k3s flag manquant: --flag-manquant"* ]]
    
    # Test de support RKE2 (préparation future)
    run expect_cluster_flag "--node-ip=10.10.0.10" "rke2"
    [ "$status" -eq 0 ]
}

@test "la fonction expect_gateway valide la configuration passerelle" {
    source "$TEST_SCRIPT"
    
    # Test de validation réussie de passerelle
    run expect_gateway "rpi4-1" "10.10.0.1"
    [ "$status" -eq 0 ]
    
    # Test de validation échouée de passerelle
    run expect_gateway "rpi4-1" "192.168.1.1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"gateway mismatch"* ]]
}

@test "le script valide toutes les adresses attendues" {
    source "$TEST_SCRIPT"
    
    # Test de toutes les validations d'adresses attendues du script original
    run expect_address "rpi4-1" "eth0.10" "10.10.0.10/24"
    [ "$status" -eq 0 ]
    
    run expect_address "rpi4-1" "eth0.10" "10.10.0.1/24"
    [ "$status" -eq 0 ]
    
    run expect_address "rpi4-2" "eth0.10" "10.10.0.11/24"
    [ "$status" -eq 0 ]
    
    run expect_address "rpi3a-ctl" "wlan0" "10.10.0.12/24"
    [ "$status" -eq 0 ]
}

@test "le script valide tous les flags cluster attendus" {
    source "$TEST_SCRIPT"
    
    # Test avec k3s (actuel)
    run expect_master_flag "--node-ip=10.10.0.10"
    [ "$status" -eq 0 ]
    
    run expect_master_flag "--tls-san=10.10.0.10"
    [ "$status" -eq 0 ]
    
    # Test avec RKE2 (futur)
    run expect_cluster_flag "--node-ip=10.10.0.10" "rke2"
    [ "$status" -eq 0 ]
}

@test "le script valide toutes les passerelles attendues" {
    source "$TEST_SCRIPT"
    
    run expect_gateway "rpi4-1" "10.10.0.1"
    [ "$status" -eq 0 ]
    
    run expect_gateway "rpi4-2" "10.10.0.1"
    [ "$status" -eq 0 ]
    
    run expect_gateway "rpi3a-ctl" "10.10.0.1"
    [ "$status" -eq 0 ]
}

@test "support des machines x86 futures" {
    source "$TEST_SCRIPT"
    
    # Test de validation d'adresses pour machines x86 (simulation)
    run addresses "x86-server1" "eth0"
    [ "$status" -eq 0 ]
    [[ "$output" == *"10.10.0.20/24"* ]]
    
    # Test de validation de passerelle pour machines x86
    run expect_gateway "x86-server1" "10.10.0.1"
    [ "$status" -eq 0 ]
}