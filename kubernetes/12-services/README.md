# 12 - Service Types (ClusterIP, NodePort, LoadBalancer, Ingress)

## What is a Service?
A Service provides a stable network endpoint to access a set of Pods. Pods are ephemeral — they get new IPs when recreated. Services solve this by providing a fixed DNS name and IP.

## Service Types Comparison

| Type | Access From | AWS Resource | Cost | Use Case |
|------|-------------|-------------|------|----------|
| **ClusterIP** | Inside cluster only | None | Free | Internal microservices |
| **NodePort** | Node IP + port (30000-32767) | Security Group rule | Free | Dev/testing |
| **LoadBalancer** | Internet via ELB DNS | NLB or CLB | ~$18/month per service | Single service exposure |
| **Ingress** | Internet via ALB DNS | ALB | ~$18/month total | Multiple services, path routing |

## Files
- `deployment.yaml` - Shared deployment (all services point to the same pods)
- `clusterip-service.yaml` - ClusterIP (internal only)
- `nodeport-service.yaml` - NodePort (node IP:30080)
- `loadbalancer-service.yaml` - LoadBalancer (AWS NLB)
- `ingress.yaml` - Ingress (AWS ALB with path routing)

## How to Run

### Step 1: Deploy the app
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f deployment.yaml
```

### Step 2: Try each service type one at a time

#### ClusterIP (internal only)
```bash
kubectl apply -f clusterip-service.yaml

# Can only access from inside the cluster
kubectl run test-pod --image=busybox -n landmark --rm -it -- wget -qO- http://landmark-clusterip.landmark:80

# Or port-forward to test locally
kubectl port-forward svc/landmark-clusterip 8080:80 -n landmark
# Then open http://localhost:8080
```

#### NodePort (node IP + static port)
```bash
kubectl apply -f nodeport-service.yaml

# Get node external IPs
kubectl get nodes -o wide

# Access via: http://<NODE_EXTERNAL_IP>:30080
# NOTE: You need to allow port 30080 in the node's Security Group
```

#### LoadBalancer (AWS NLB)
```bash
kubectl apply -f loadbalancer-service.yaml

# Get the NLB DNS name
kubectl get svc landmark-loadbalancer -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Access via the DNS name on port 80
```

#### Ingress (AWS ALB with path routing)
```bash
# Requires ClusterIP service to exist (Ingress routes to it)
kubectl apply -f clusterip-service.yaml
kubectl apply -f ingress.yaml

# Get the ALB DNS name
kubectl get ingress landmark-ingress-demo -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Visual Flow

```
                    ┌─────────────────────────────────────────────────┐
                    │                  CLUSTER                         │
                    │                                                  │
  Internet ──────► │  LoadBalancer (NLB) ──► Pod-1                   │
                    │                        ──► Pod-2                │
  Internet ──────► │  Ingress (ALB) ──► ClusterIP ──► Pod-1         │
                    │                                 ──► Pod-2       │
                    │                                                  │
  Node IP:30080 ──►│  NodePort ──► Pod-1                             │
                    │              ──► Pod-2                           │
                    │                                                  │
  Inside cluster ──►│  ClusterIP ──► Pod-1                           │
                    │               ──► Pod-2                         │
                    └─────────────────────────────────────────────────┘
```

## Prerequisites
- Namespace `landmark` must exist (step 01)

### For LoadBalancer Service
AWS Load Balancer Controller must be installed:
```bash
# 1. Create IAM OIDC provider
eksctl utils associate-iam-oidc-provider --cluster landmark-eks-cluster --region us-east-1 --approve

# 2. Download IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.1/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

# 3. Create IRSA service account
eksctl create iamserviceaccount \
  --cluster=landmark-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# 4. Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=landmark-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 5. Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### For NodePort
Open the port in the worker node Security Group:
```bash
# Get the security group ID of the worker nodes
SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:kubernetes.io/cluster/landmark-eks-cluster,Values=owned" --query 'SecurityGroups[0].GroupId' --output text)

# Allow inbound traffic on port 30080
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 30080 --cidr 0.0.0.0/0
```

### For Ingress
Same AWS Load Balancer Controller as LoadBalancer (see above). The controller handles both NLB (for LoadBalancer services) and ALB (for Ingress resources).

## Cleanup
```bash
kubectl delete -f ingress.yaml
kubectl delete -f loadbalancer-service.yaml
kubectl delete -f nodeport-service.yaml
kubectl delete -f clusterip-service.yaml
kubectl delete -f deployment.yaml
```
