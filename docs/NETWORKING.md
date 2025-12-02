# NETWORKING

## VLANs et plan d'adressage
- **INFRA (VLAN 10)** : 10.10.0.0/24, gateway 10.10.0.1.
- **PRO (VLAN 20)** : 10.20.0.0/24, gateway 10.20.0.1.
- **PERSO (VLAN 30)** : 10.30.0.0/24, gateway 10.30.0.1.
- **IOT (VLAN 40)** : 10.40.0.0/24, gateway 10.40.0.1.

Exemple INFRA :
- rpi4-1 : 10.10.0.1 (gateway) + 10.10.0.10 (k3s) sur `eth0.10`.
- rpi4-2 : 10.10.0.11/24 gw 10.10.0.1.
- rpi3a-ctl : 10.10.0.12/24 gw 10.10.0.1 via Wi-Fi.

Les définitions VLAN/hosts sont centralisées dans `infra/topology.nix` et consommées par `modules/topology.nix` pour éviter les doublons.

## Rôle du routeur (`roles.router`)
- Génère `networking.vlans`, NAT et règles nftables à partir de `roles.router.vlans`.
- `forwardRules` et `ingressTcpPorts` décrivent les flux inter-VLAN et WAN.
- DHCP : plages dérivées de `dhcpRange` et `defaultGatewayIndex` par VLAN.
- WAN 4G : SSID/PSK fournis via `roles.router.wan.{ssid,pskEnvVar,priority}` ; le PSK est injecté via `networking.wireless.secretsFile` (tmpfs).

## Wi-Fi et PSK
- Fichier runtime `/run/secrets/wpa_supplicant.env` (tmpfs) avec `WAN_4G_PSK` et `INFRA_K3S_PSK`.
- Jamais de secret en clair dans Nix ni dans le store ; utiliser SOPS/age ou `LoadCredential` pour le provisionnement.

## Adressage k3s
- `topology.k3s.apiAddress` et `serverAddr` définissent le SAN/API du cluster.
- Les rôles master/worker par hôte sont définis dans `topology.hosts.<hostname>.k3s`.
- Les deux RPi4B sont master+worker (`master-worker`) pour la haute disponibilité, rpi3a-ctl est `control-plane-only` avec taint NoSchedule.
