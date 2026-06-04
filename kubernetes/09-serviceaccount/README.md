# 09 - ServiceAccount

## What is a ServiceAccount?
A ServiceAccount provides an identity for pods. It controls:
- **RBAC** — what Kubernetes API actions the pod can perform
- **IRSA** (IAM Roles for Service Accounts) — what AWS services the pod can access

By default, pods use the `default` ServiceAccount which has no permissions.

## Files
- `serviceaccount.yaml` - ServiceAccount with IRSA annotation
- `role.yaml` - Role + RoleBinding (RBAC permissions within the namespace)
- `deployment.yaml` - Deployment that uses the ServiceAccount
- `service.yaml` - LoadBalancer Service to expose the app

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f role.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Verify
```bash
kubectl get sa -n landmark
kubectl describe sa landmark-sa -n landmark

# Check that the pod is using the service account
kubectl get pods -n landmark -l app=landmark-sa-app -o jsonpath='{.items[0].spec.serviceAccountName}'

# Verify RBAC - exec into pod and try API calls
kubectl exec -it $(kubectl get pods -n landmark -l app=landmark-sa-app -o jsonpath='{.items[0].metadata.name}') -n landmark -- \
  wget -qO- https://kubernetes.default.svc/api/v1/namespaces/landmark/pods --header="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" --no-check-certificate
```

## Access the Application
```bash
kubectl get svc landmark-sa-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Prerequisites
- Namespace `landmark` must exist (step 01)
- AWS Load Balancer Controller installed (see 02-pod/README.md)

### Setting up IRSA (IAM Roles for Service Accounts)
```bash
# 1. Ensure OIDC provider exists
eksctl utils associate-iam-oidc-provider --cluster landmark-eks-cluster --region us-east-1 --approve

# 2. Create IAM role and link to the ServiceAccount
eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster \
  --namespace=landmark \
  --name=landmark-sa \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve --override-existing-serviceaccounts

# 3. Verify the annotation was added
kubectl describe sa landmark-sa -n landmark
```

## Cleanup
```bash
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f role.yaml
kubectl delete -f serviceaccount.yaml
```
