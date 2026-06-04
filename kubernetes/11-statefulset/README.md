# 11 - StatefulSet

## What is a StatefulSet?
A StatefulSet manages stateful applications. Unlike Deployments, it provides:
- **Stable pod names** — `pod-0`, `pod-1`, `pod-2` (not random hashes)
- **Stable storage** — each pod gets its own PVC that persists across restarts
- **Ordered operations** — pods are created/deleted in order (0→1→2, then 2→1→0)
- **Stable DNS** — each pod gets a predictable hostname

## StatefulSet vs Deployment
| Feature | Deployment | StatefulSet |
|---------|-----------|-------------|
| Pod names | Random (e.g., `app-7f8b9c`) | Ordered (e.g., `app-0`, `app-1`) |
| Storage | Shared PVC (or none) | Each pod gets its own PVC |
| Scaling | All at once | One at a time, in order |
| Use case | Stateless apps (web servers) | Stateful apps (databases) |

## Files
- `secret.yaml` - MySQL root password
- `statefulset.yaml` - MySQL StatefulSet with volumeClaimTemplates
- `headless-service.yaml` - Headless Service for stable DNS names

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f ../10-pv-pvc/storageclass.yaml   # Needs the gp3 StorageClass
kubectl apply -f secret.yaml
kubectl apply -f headless-service.yaml
kubectl apply -f statefulset.yaml
```

## Verify
```bash
# Watch pods come up IN ORDER (0 first, then 1)
kubectl get pods -n landmark -l app=landmark-mysql -w

# Check each pod has its own PVC
kubectl get pvc -n landmark

# Check stable DNS names
kubectl run dns-test --image=busybox -n landmark --rm -it -- nslookup landmark-mysql-0.landmark-mysql-headless.landmark.svc.cluster.local

# Connect to MySQL
kubectl exec -it landmark-mysql-0 -n landmark -- mysql -u root -pLandmarkPass123 -e "SHOW DATABASES;"
```

## Experiments
```bash
# Delete pod-0 — it comes back as pod-0 (same name, same PVC)
kubectl delete pod landmark-mysql-0 -n landmark
kubectl get pods -n landmark -w

# Scale up — pod-2 is created (in order)
kubectl scale statefulset landmark-mysql -n landmark --replicas=3

# Scale down — pod-2 is deleted first (reverse order)
kubectl scale statefulset landmark-mysql -n landmark --replicas=2
```

## Prerequisites
- Namespace `landmark` must exist (step 01)
- StorageClass from step 10 must exist

### AWS EBS CSI Driver (REQUIRED)
StatefulSet uses volumeClaimTemplates which need the EBS CSI driver:
```bash
# 1. Create IAM role
eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster \
  --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --attach-policy-arn=arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# 2. Install EBS CSI driver add-on
aws eks create-addon \
  --cluster-name landmark-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_EBS_CSI_DriverRole

# 3. Verify
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

## Cleanup
```bash
kubectl delete -f statefulset.yaml
kubectl delete -f headless-service.yaml
kubectl delete -f secret.yaml
# PVCs are NOT automatically deleted — delete manually
kubectl delete pvc -l app=landmark-mysql -n landmark
```
