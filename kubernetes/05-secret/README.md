# 05 - Secret

## What is a Secret?
A Secret stores sensitive data (passwords, API keys, tokens) in base64-encoded format. Unlike ConfigMaps, Secrets are meant for confidential data and can be encrypted at rest in etcd.

## Files
- `secret.yaml` - Secret with DB_PASSWORD and API_KEY
- `deployment.yaml` - Deployment that injects both ConfigMap and Secret as env vars
- `service.yaml` - LoadBalancer Service to expose the app

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f ../04-configmap/configmap.yaml   # Deployment also uses the configmap
kubectl apply -f secret.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Verify
```bash
kubectl get secrets -n landmark
kubectl describe secret landmark-secret -n landmark

# Check secret values inside a pod (they appear as plain text env vars in the container)
kubectl exec -it $(kubectl get pods -n landmark -l app=landmark-secret-app -o jsonpath='{.items[0].metadata.name}') -n landmark -- env | grep -E "DB_PASSWORD|API_KEY"
```

## Access the Application
```bash
kubectl get svc landmark-secret-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Creating Secrets
```bash
# From literal values
kubectl create secret generic my-secret --from-literal=password=mypass -n landmark

# From a file
kubectl create secret generic my-secret --from-file=./credentials.txt -n landmark

# Encode manually
echo -n "mypassword" | base64
# Output: bXlwYXNzd29yZA==
```

## Prerequisites
- Namespace `landmark` must exist (step 01)
- ConfigMap from step 04 must exist (deployment references it)
- AWS Load Balancer Controller installed (see 02-pod/README.md)

### (Optional) External Secrets Operator
For production, use External Secrets Operator to sync secrets from AWS Secrets Manager:
```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Create IAM policy for Secrets Manager access
aws iam create-policy --policy-name ExternalSecretsPolicy --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"],
      "Resource": "*"
    }
  ]
}'

# Create IRSA service account
eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster \
  --namespace=landmark \
  --name=external-secrets-sa \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/ExternalSecretsPolicy \
  --approve

# Create a SecretStore pointing to AWS Secrets Manager
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secret-store
  namespace: landmark
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
EOF

# Create an ExternalSecret that syncs from AWS Secrets Manager
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: landmark-external-secret
  namespace: landmark
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: landmark-secret
  data:
  - secretKey: DB_PASSWORD
    remoteRef:
      key: landmark/db-password
  - secretKey: API_KEY
    remoteRef:
      key: landmark/api-key
EOF
```

## Cleanup
```bash
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f secret.yaml
```
