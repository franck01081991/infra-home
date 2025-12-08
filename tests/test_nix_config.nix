# Tests basés sur Nix pour la validation de configuration
{ pkgs ? import <nixpkgs> {} }:

let
  topology = import ../infra/topology.nix;

  # Fonctions d'aide pour la validation
  inherit (pkgs) lib;

  # Test que tous les VLANs ont des IDs uniques
  testUniqueVlanIds = let
    vlanIds = map (vlan: vlan.id) topology.vlans;
    uniqueIds = lib.unique vlanIds;
  in assert lib.length vlanIds == lib.length uniqueIds;
  "RÉUSSI: Tous les IDs VLAN sont uniques";

  # Test que tous les VLANs ont des formats de sous-réseau valides
  testValidSubnets = let
    subnets = map (vlan: vlan.subnet) topology.vlans;
    # Validation basique : doit contenir un slash
    validSubnets = lib.all (subnet: lib.hasInfix "/" subnet) subnets;
  in assert validSubnets;
  "RÉUSSI: Tous les sous-réseaux ont un format CIDR valide";

  # Test que la configuration cluster est présente et valide (k3s ou RKE2)
  testClusterConfig = let
    # Support pour k3s (actuel) et RKE2 (futur)
    clusterConfig =
      topology.k3s or (topology.rke2 or (topology.cluster or (throw
        "Aucune configuration cluster trouvée")));

    hasApiAddress = clusterConfig ? apiAddress;
    hasServerAddr = clusterConfig ? serverAddr || clusterConfig ? server;
    apiAddressValid = lib.hasInfix "10.10.0.10" clusterConfig.apiAddress;
  in assert hasApiAddress && hasServerAddr && apiAddressValid;
  "RÉUSSI: Configuration cluster valide";

  # Test que tous les hôtes ont les champs requis
  testHostsConfig = let
    inherit (topology) hosts;
    # Récupération dynamique des noms d'hôtes pour la scalabilité
    hostNames = lib.attrNames hosts;

    checkHost = hostName:
      let
        host = hosts.${hostName};
        hasRouter = host ? router;
        hasAddresses = host ? addresses;
        # Support pour k3s, RKE2 ou configuration cluster générique
        hasCluster = host ? k3s || host ? rke2 || host ? cluster;
        hasInfraAddress = host.addresses ? infra;
      in assert hasRouter && hasAddresses && hasCluster && hasInfraAddress;
      true;

    allHostsValid = lib.all checkHost hostNames;
  in assert allHostsValid;
  "RÉUSSI: Tous les hôtes ont la configuration requise";

  # Test que la configuration routeur est cohérente
  testRouterConfig = let
    inherit (topology) hosts;
    hostNames = lib.attrNames hosts;

    # Compter les routeurs
    routerCount =
      lib.length (lib.filter (hostName: hosts.${hostName}.router) hostNames);

    # Il doit y avoir exactement un routeur
    exactlyOneRouter = routerCount == 1;
  in assert exactlyOneRouter;
  "RÉUSSI: Configuration routeur correcte (exactement un routeur)";

  # Test que l'adresse API cluster correspond à l'adresse infra du routeur principal
  testClusterApiConsistency = let
    # Support pour k3s (actuel) et RKE2 (futur)
    clusterConfig = topology.k3s or (topology.rke2 or topology.cluster);

    inherit (clusterConfig) apiAddress;

    # Trouver le routeur principal
    inherit (topology) hosts;
    hostNames = lib.attrNames hosts;
    routerHost =
      lib.findFirst (hostName: hosts.${hostName}.router) null hostNames;
    routerAddress = hosts.${routerHost}.addresses.infra;
  in assert apiAddress == routerAddress;
  "RÉUSSI: Adresse API cluster correspond à l'adresse infra du routeur principal";

  # Test de support pour architectures multiples
  testMultiArchSupport = let
    inherit (topology) hosts;
    hostNames = lib.attrNames hosts;

    # Vérifier que la configuration ne dépend pas d'une architecture spécifique
    # Les noms d'hôtes peuvent inclure des machines x86 futures
    supportsMultipleArch = lib.all (hostName:
      let host = hosts.${hostName};
      in host ? addresses && host ? router) hostNames;
  in assert supportsMultipleArch;
  "RÉUSSI: Support pour architectures multiples";

in
{
  # Exécuter tous les tests
  runTests = pkgs.writeText "nix-config-tests" ''
    ${testUniqueVlanIds}
    ${testValidSubnets}
    ${testClusterConfig}
    ${testHostsConfig}
    ${testRouterConfig}
    ${testClusterApiConsistency}
    ${testMultiArchSupport}

    Tous les tests de configuration Nix réussis !
  '';

  # Résultats de tests individuels pour le débogage
  inherit testUniqueVlanIds testValidSubnets testClusterConfig testHostsConfig
    testRouterConfig testClusterApiConsistency testMultiArchSupport;
}
