# ARCHITECTURE

Vue d'ensemble du homelab : routeur NixOS rpi4-1 (WAN 4G + VLAN INFRA/PRO/PERSO/IOT) et cluster k3s HA (rpi4-1 master/worker, rpi4-2 worker, rpi3a-ctl control-plane-only Wi-Fi, téléphones Android rootés workers ARM). FluxCD applique les manifestes `clusters/base → review → staging → prod`; OpenBao stocke les secrets runtime exposés via External Secrets Operator.

Pour les détails opérationnels :
- Réseau : [`docs/NETWORKING.md`](NETWORKING.md)
- GitOps : [`docs/GITOPS.md`](GITOPS.md)
- Secrets : [`docs/SECRETS.md`](SECRETS.md)
- Hôtes : [`docs/HOSTS.md`](HOSTS.md)
- Téléphones : [`docs/PHONES.md`](PHONES.md)

ADR : [`docs/adr/0001-gitops-bootstrap.md`](adr/0001-gitops-bootstrap.md), [`docs/adr/0002-topology-datasource.md`](adr/0002-topology-datasource.md).
