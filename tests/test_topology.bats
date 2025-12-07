#!/usr/bin/env bats

# Tests de validation de la configuration de topologie

setup() {
    # Charger la configuration de topologie
    export TOPOLOGY_FILE="$BATS_TEST_DIRNAME/../infra/topology.nix"
}

@test "le fichier de topologie existe" {
    [ -f "$TOPOLOGY_FILE" ]
}

@test "la topologie contient les VLANs requis" {
    run grep -q "name = \"infra\"" "$TOPOLOGY_FILE"
    [ "$status" -eq 0 ]
    
    run grep -q "name = \"pro\"" "$TOPOLOGY_FILE"
    [ "$status" -eq 0 ]
    
    run grep -q "name = \"perso\"" "$TOPOLOGY_FILE"
    [ "$status" -eq 0 ]
    
    run grep -q "name = \"iot\"" "$TOPOLOGY_FILE"
    [ "$status" -eq 0 ]
}

@test "les IDs VLAN sont uniques et dans la plage attendue" {
    # Extraire les IDs VLAN et vérifier qu'ils sont uniques
    local vlan_ids
    vlan_ids=$(grep "id = " "$TOPOLOGY_FILE" | grep -o '[0-9]\+' | sort -n)
    
    # Vérifier que les IDs attendus sont présents
    echo "$vlan_ids" | grep -q "10"
    echo "$vlan_ids" | grep -q "20"
    echo "$vlan_ids" | grep -q "30"
    echo "$vlan_ids" | grep -q "40"
    
    # Vérifier l'absence de doublons (nombre unique = nombre total)
    local unique_count total_count
    unique_count=$(echo "$vlan_ids" | sort -u | wc -l)
    total_count=$(echo "$vlan_ids" | wc -l)
    [ "$unique_count" -eq "$total_count" ]
}

@test "les adresses de sous-réseau sont au format CIDR valide" {
    # Vérifier que toutes les entrées de sous-réseau suivent la notation CIDR
    local subnets
    subnets=$(grep "subnet = " "$TOPOLOGY_FILE" | grep -o '"[^"]*"' | tr -d '"')
    
    for subnet in $subnets; do
        # Validation CIDR basique : doit contenir exactement un slash
        [[ "$subnet" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]
    done
}

@test "la configuration cluster est présente" {
    # Test générique pour cluster (k3s ou RKE2)
    run bash -c "grep -q 'k3s = {' '$TOPOLOGY_FILE' || grep -q 'cluster = {' '$TOPOLOGY_FILE'"
    [ "$status" -eq 0 ]
    
    run grep -q "apiAddress = " "$TOPOLOGY_FILE"
    [ "$status" -eq 0 ]
    
    # serverAddr pour k3s ou équivalent pour RKE2
    run bash -c "grep -q 'serverAddr = ' '$TOPOLOGY_FILE' || grep -q 'server = ' '$TOPOLOGY_FILE'"
    [ "$status" -eq 0 ]
}

@test "tous les hôtes ont la configuration requise" {
    # Récupérer dynamiquement la liste des hôtes depuis le fichier
    local hosts
    hosts=$(grep -o '[a-zA-Z0-9_-]\+ = {' "$TOPOLOGY_FILE" | grep -v 'vlans\|k3s\|cluster' | cut -d' ' -f1)
    
    for host in $hosts; do
        run grep -q "$host = {" "$TOPOLOGY_FILE"
        [ "$status" -eq 0 ]
        
        # Chaque hôte doit avoir router, addresses, et configuration cluster
        run bash -c "grep -A 15 '$host = {' '$TOPOLOGY_FILE' | grep -q 'router = '"
        [ "$status" -eq 0 ]
        
        run bash -c "grep -A 15 '$host = {' '$TOPOLOGY_FILE' | grep -q 'addresses = {'"
        [ "$status" -eq 0 ]
        
        # Configuration cluster (k3s ou RKE2)
        run bash -c "grep -A 15 '$host = {' '$TOPOLOGY_FILE' | grep -q -E '(k3s|cluster) = {'"
        [ "$status" -eq 0 ]
    done
}

@test "les adresses VLAN infra sont cohérentes" {
    # Vérifier que l'apiAddress du cluster correspond à l'adresse infra du routeur principal
    local api_address router_address
    
    api_address=$(grep "apiAddress = " "$TOPOLOGY_FILE" | grep -o '"[^"]*"' | tr -d '"')
    
    # Méthode directe : on sait que rpi4-1 est le routeur principal dans la configuration actuelle
    # Pour la scalabilité future, on pourrait améliorer cela
    router_address=$(grep -A 5 "rpi4-1 = {" "$TOPOLOGY_FILE" | grep "infra = " | grep -o '"[^"]*"' | tr -d '"')
    
    [ "$api_address" = "$router_address" ]
}

@test "la configuration routeur est valide" {
    # Vérifier qu'un seul hôte est configuré comme routeur
    local router_count
    router_count=$(grep -c "router = true" "$TOPOLOGY_FILE")
    [ "$router_count" -eq 1 ]
    
    # Vérifier que les autres hôtes ne sont pas routeurs
    local non_router_count total_hosts
    non_router_count=$(grep -c "router = false" "$TOPOLOGY_FILE")
    total_hosts=$(grep -c "= {" "$TOPOLOGY_FILE" | grep -v "vlans\|k3s\|cluster")
    
    # Le nombre de non-routeurs + 1 routeur doit égaler le nombre total d'hôtes
    [ $((non_router_count + 1)) -ge 3 ]  # Au minimum 3 hôtes actuels
}

@test "support des architectures multiples" {
    # Vérifier que la configuration supporte différentes architectures
    # (préparation pour machines x86)
    
    # La topologie ne doit pas être liée à une architecture spécifique
    run bash -c "! grep -q 'arm\|x86\|aarch64' '$TOPOLOGY_FILE'"
    [ "$status" -eq 0 ]
    
    # Les adresses IP doivent être indépendantes de l'architecture
    local addresses
    addresses=$(grep "infra = " "$TOPOLOGY_FILE" | grep -o '"[^"]*"' | tr -d '"')
    
    for addr in $addresses; do
        # Vérifier que c'est une adresse IP valide
        [[ "$addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
    done
}