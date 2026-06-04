# 13 - External Secrets (AWS Secrets Manager → Kubernetes Secrets)

## What is External Secrets Operator?
The External Secrets Operator (ESO) syncs secrets from external providers (AWS Secrets Manager, SSM Parameter Store, HashiCorp Vault, etc.) into Kubernetes Secrets automatically. This means:
- **No secrets in Git** — secrets live in AWS Secrets Manager
- **Auto-rotation** — secrets refresh on a schedule (e.g., every hour)
- **Single source of truth** — manage secrets in AWS, Kubernetes stays in sync
- **No manual base64 encoding** — ESO handles it

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  AWS                                                              │
│  ┌─────────────────────┐                                         │
│  │  Secrets Manager     │                                         │
│  │  - landmark/database │◄──── You create secrets here            │
│  │  - landmark/api-key  │                                         │
│  └──────────┬──────────┘                                         │
└─────────────┼────────────────────────────────────────────────────┘
              │ (IRSA - IAM Role for Service Account)
              ▼
┌──────────────────────────────────────────────────────────────────┐
│  EKS Cluster                                                      │
│                                                                    │
│  ┌──────────────────┐     ┌──────────────────┐                   │
│  │  SecretStore       │────►│  ExternalSecret   │                  │
│  │  (HOW to connect) │     │  (WHAT to fetch)  │                  │
│  └──────────────────┘     └────────┬─────────┘                   │
│                                     │ creates/syncs                │
│                                     ▼                              │
│                            ┌──────────────────┐                   │
│                            │  K8s Secret       │                   │
│                            │  (landmark-app-   │                   │
│                            │   secret)         │                   │
│                            └────────┬─────────┘                   │
│                                     │ consumed by                  │
│                                     ▼                              │
│                            ┌──────────────────┐                   │
│                            │  Deployment Pods  │                   │
│                            │  (env vars)       │                   │
│                            └──────────────────┘                   │
└──────────────────────────────────────────────────────────────────┘
```

## Files
- `serviceaccount.yaml` - ServiceAccount with IRSA for AWS Secrets Manager access
- `secretstore.yaml` - SecretStore (defines connection to AWS Secrets Manager)
- `externalsecret.yaml` - ExternalSecret (defines what secrets to sync)
- `deployment.yaml` - Deployment that consumes the synced secret
- `service.yaml` - LoadBalancer Service to expose the app

---

## Prerequisites

### Step 1: Install External Secrets Operator CRDs

```bash
# Add the Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install the operator (this installs the CRDs + controller)
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true

# Verify the installation
kubectl get pods -n external-secrets
kubectl get crd | grep external-secrets
```

Expected CRDs:
```
externalsecrets.external-secrets.io
secretstores.external-secrets.io
clustersecretstores.external-secrets.io
```

### Step 2: Create IAM Policy for Secrets Manager Access

```bash
# Create the IAM policy
cat <<EOF > es-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:landmark/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:ListSecrets"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name ExternalSecretsPolicy \
  --policy-document file://es-policy.json
```

### Step 3: Create IRSA (IAM Role for Service Account)

```bash
# Ensure OIDC provider exists
eksctl utils associate-iam-oidc-provider \
  --cluster landmark-eks-cluster \
  --region us-east-1 \
  --approve

# Create the service account with IAM role
eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster \
  --namespace=landmark \
  --name=external-secrets-sa \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/ExternalSecretsPolicy \
  --approve --override-existing-serviceaccounts
```

### Step 4: Create Secrets in AWS Secrets Manager

```bash
# Create a JSON secret for database credentials
aws secretsmanager create-secret \
  --name landmark/database \
  --secret-string '{"host":"landmark-db.cluster-abc123.us-east-1.rds.amazonaws.com","username":"admin","password":"SuperSecretPass123!"}' \
  --region us-east-1

# Create a plain text secret for API key
aws secretsmanager create-secret \
  --name landmark/api-key \
  --secret-string "sk-landmark-prod-abc123xyz789" \
  --region us-east-1
```

---

## How to Run

```bash
# 1. Ensure namespace exists
kubectl apply -f ../01-namespace/namespace.yaml

# 2. Apply the ServiceAccount (skip if created via eksctl above)
kubectl apply -f serviceaccount.yaml

# 3. Create the SecretStore
kubectl apply -f secretstore.yaml

# 4. Create the ExternalSecret (this triggers the sync)
kubectl apply -f externalsecret.yaml

# 5. Deploy the app that uses the secret
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Verify

```bash
# Check SecretStore is valid
kubectl get secretstore -n landmark
kubectl describe secretstore aws-secret-store -n landmark
# STATUS should show: Valid

# Check ExternalSecret is syncing
kubectl get externalsecret -n landmark
kubectl describe externalsecret landmark-external-secret -n landmark
# STATUS should show: SecretSynced

# Check the Kubernetes Secret was created
kubectl get secret landmark-app-secret -n landmark
kubectl get secret landmark-app-secret -n landmark -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Check env vars inside the pod
kubectl exec -it $(kubectl get pods -n landmark -l app=landmark-es-app -o jsonpath='{.items[0].metadata.name}') -n landmark -- env | grep -E "DB_|API_"
```

## Access the Application
```bash
kubectl get svc landmark-es-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## Troubleshooting

### SecretStore shows "Invalid"
```bash
kubectl describe secretstore aws-secret-store -n landmark
# Check Events section for errors

# Common issues:
# - IRSA not configured: check SA annotation
kubectl get sa external-secrets-sa -n landmark -o yaml
# - IAM policy too restrictive: check the resource ARN matches your secret names
```

### ExternalSecret shows "SecretSyncedError"
```bash
kubectl describe externalsecret landmark-external-secret -n landmark

# Common issues:
# - Secret doesn't exist in AWS: verify with
aws secretsmanager get-secret-value --secret-id landmark/database --region us-east-1
# - Wrong property name: for JSON secrets, the "property" must match a key in the JSON
```

### Pods stuck in CrashLoopBackOff
```bash
# The K8s secret might not exist yet
kubectl get secret landmark-app-secret -n landmark
# If missing, check the ExternalSecret status above
```

---

## Rotating Secrets

When you update a secret in AWS Secrets Manager:
```bash
aws secretsmanager update-secret \
  --secret-id landmark/database \
  --secret-string '{"host":"new-host.rds.amazonaws.com","username":"admin","password":"NewPassword456!"}' \
  --region us-east-1
```

The ExternalSecret will pick up the change on the next `refreshInterval` (1 hour by default). To force immediate sync:
```bash
# Delete and recreate the ExternalSecret
kubectl delete externalsecret landmark-external-secret -n landmark
kubectl apply -f externalsecret.yaml

# Or annotate to trigger reconciliation
kubectl annotate externalsecret landmark-external-secret -n landmark force-sync=$(date +%s) --overwrite
```

> **Note:** Pods need to be restarted to pick up new env var values. Use a tool like [Reloader](https://github.com/stakater/Reloader) to auto-restart pods when secrets change.

---

## ClusterSecretStore (Optional)

If you want a single SecretStore shared across ALL namespaces:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-cluster-secret-store
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: landmark
```

Then reference it in ExternalSecret:
```yaml
spec:
  secretStoreRef:
    name: aws-cluster-secret-store
    kind: ClusterSecretStore
```

---

## Cleanup
```bash
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f externalsecret.yaml
kubectl delete -f secretstore.yaml
kubectl delete -f serviceaccount.yaml

# (Optional) Remove secrets from AWS
aws secretsmanager delete-secret --secret-id landmark/database --force-delete-without-recovery --region us-east-1
aws secretsmanager delete-secret --secret-id landmark/api-key --force-delete-without-recovery --region us-east-1

# (Optional) Uninstall the operator
helm uninstall external-secrets -n external-secrets
kubectl delete namespace external-secrets
```
