# OpenBao dans k3s

## Installation

```bash
helm repo add openbao https://openbao.github.io/openbao-helm
helm repo update

kubectl create namespace openbao

helm install openbao openbao/openbao \
  -n openbao \
  -f k8s/openbao/values-openbao.yaml
```

## Bootstrap

```bash
./k8s/openbao/bootstrap-openbao.sh > openbao-init.txt
```

Puis récupérer et stocker en lieu sûr l'Unseal Key et le Root Token.
