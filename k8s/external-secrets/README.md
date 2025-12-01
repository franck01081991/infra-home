# External Secrets Operator + OpenBao

## Installer ESO

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

kubectl create namespace external-secrets

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets
```

## SecretStore & ExternalSecret

```bash
kubectl apply -f k8s/external-secrets/secretstore-openbao.yaml
kubectl apply -f k8s/external-secrets/externalsecret-example.yaml
```
