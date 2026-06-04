# 10 - PersistentVolume (PV) & PersistentVolumeClaim (PVC)

## What are PV and PVC?
- **PersistentVolume (PV)** — a piece of storage provisioned in the cluster (like an EBS volume)
- **PersistentVolumeClaim (PVC)** — a request for storage by a pod
- **StorageClass** — defines HOW storage is dynamically provisioned (EBS type, IOPS, etc.)

On AWS EKS, the EBS CSI Driver dynamically creates EBS volumes when a PVC is created.

## Files
- `storageclass.yaml` - StorageClass using gp3 EBS volumes
- `pvc.yaml` - PVC requesting 5Gi of storage
- `deployment.yaml` - Deployment that mounts the PVC at `/data`
- `service.yaml` - LoadBalancer Service to expose the app

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f storageclass.yaml
kubectl apply -f pvc.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Verify
```bash
kubectl get storageclass
kubectl get pvc -n landmark
kubectl get pv

# Check the EBS volume was created
kubectl describe pvc landmark-pvc -n landmark

# Write data and verify persistence
kubectl exec -it $(kubectl get pods -n landmark -l app=landmark-pvc-app -o jsonpath='{.items[0].metadata.name}') -n landmark -- sh -c "echo 'hello persistent world' > /data/test.txt"

# Delete the pod (deployment recreates it)
kubectl delete pod -l app=landmark-pvc-app -n landmark

# Verify data survived
kubectl exec -it $(kubectl get pods -n landmark -l app=landmark-pvc-app -o jsonpath='{.items[0].metadata.name}') -n landmark -- cat /data/test.txt
```

## Access the Application
```bash
kubectl get svc landmark-pvc-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Prerequisites
- Namespace `landmark` must exist (step 01)
- AWS Load Balancer Controller installed (see 02-pod/README.md)

### AWS EBS CSI Driver (REQUIRED)
```bash
# 1. Create IAM role for the EBS CSI driver
eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster \
  --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --attach-policy-arn=arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# 2. Install the EBS CSI driver as an EKS add-on
aws eks create-addon \
  --cluster-name landmark-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::<ACCOUNT_ID>:role/AmazonEKS_EBS_CSI_DriverRole

# 3. Verify
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

## Important Notes
- `ReadWriteOnce` means the volume can only be mounted by pods on a **single node**
- Replicas must be 1 for RWO volumes (use StatefulSet for multiple replicas with individual volumes)
- `WaitForFirstConsumer` ensures the EBS volume is created in the same AZ as the pod

## Cleanup
```bash
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f pvc.yaml
kubectl delete -f storageclass.yaml
```
