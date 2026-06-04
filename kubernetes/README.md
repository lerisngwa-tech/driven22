# Kubernetes Incremental Demo - Landmark Technology

Each folder is a self-contained experiment. Apply them in order to learn Kubernetes concepts incrementally. Each folder has its own README with explanations, prerequisites, and how to run.

---

## Structure

| # | Folder | Concept | What You Learn |
|---|--------|---------|----------------|
| 01 | namespace | Namespace | Resource isolation |
| 02 | pod | Pod + Service | Smallest unit, no self-healing |
| 03 | deployment | Deployment + Service | Self-healing, scaling, rolling updates |
| 04 | configmap | ConfigMap + Deployment + Service | Externalize configuration |
| 05 | secret | Secret + Deployment + Service | Handle sensitive data |
| 06 | ingress | Ingress + Deployment + Service | Single entry point, path routing |
| 07 | hpa | HPA + Deployment + Service | Auto-scaling based on load |
| 08 | daemonset | DaemonSet | One pod per node (logging/monitoring) |
| 09 | serviceaccount | ServiceAccount + RBAC + IRSA | Pod identity and permissions |
| 10 | pv-pvc | StorageClass + PVC + Deployment | Persistent storage with EBS |
| 11 | statefulset | StatefulSet + Headless Service | Stateful apps (databases) |
| 12 | services | All Service Types | ClusterIP, NodePort, LoadBalancer, Ingress |
| 13 | external-secrets | SecretStore + ExternalSecret | Sync secrets from AWS Secrets Manager |

---

## Prerequisites (AWS EKS)

### 1. EKS Cluster
Deploy using the `terraform/` folder in this repo:
```bash
cd ../terraform
terraform init && terraform apply
aws eks update-kubeconfig --region us-east-1 --name landmark-eks-cluster
```

### 2. AWS Load Balancer Controller
Required for: LoadBalancer services, Ingress
```bash
eksctl utils associate-iam-oidc-provider --cluster landmark-eks-cluster --region us-east-1 --approve

curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.1/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy --approve

helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=landmark-eks-cluster \
  --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
```

### 3. EBS CSI Driver
Required for: PV/PVC, StatefulSet
```bash
eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --attach-policy-arn=arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --approve

aws eks create-addon --cluster-name landmark-eks-cluster --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_EBS_CSI_DriverRole
```

### 4. Metrics Server
Required for: HPA
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 5. External Secrets Operator (Optional)
For syncing secrets from AWS Secrets Manager:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

---

## Quick Start
```bash
# Apply everything in order
kubectl apply -f 01-namespace/
kubectl apply -f 02-pod/
kubectl apply -f 03-deployment/
kubectl apply -f 04-configmap/
kubectl apply -f 05-secret/
kubectl apply -f 06-ingress/
kubectl apply -f 07-hpa/
kubectl apply -f 08-daemonset/
kubectl apply -f 09-serviceaccount/
kubectl apply -f 10-pv-pvc/
kubectl apply -f 11-statefulset/
kubectl apply -f 12-services/
kubectl apply -f 13-external-secrets/
```

## Full Cleanup
```bash
kubectl delete namespace landmark
```
