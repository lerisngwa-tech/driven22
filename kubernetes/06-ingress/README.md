# 06 - Ingress

## What is an Ingress?
An Ingress is a single entry point that routes external HTTP/HTTPS traffic to multiple services based on URL paths or hostnames. It replaces the need for multiple LoadBalancer services (which each cost money on AWS).

## Files
- `ingress.yaml` - ALB Ingress with path-based routing
- `deployment.yaml` - Deployment behind the Ingress
- `service.yaml` - ClusterIP Service (Ingress handles external access)

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f ../04-configmap/configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

## Verify
```bash
kubectl get ingress -n landmark
kubectl describe ingress landmark-ingress -n landmark
```

## Access the Application
```bash
# Get the ALB DNS name
kubectl get ingress landmark-ingress -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
Open the URL in your browser — traffic flows: Internet → ALB → Service → Pods.

## Prerequisites
- Namespace `landmark` must exist (step 01)
- ConfigMap from step 04 must exist

### AWS Load Balancer Controller (REQUIRED)
The ALB Ingress Controller must be installed to provision an Application Load Balancer:
```bash
# 1. Create IAM OIDC provider
eksctl utils associate-iam-oidc-provider --cluster landmark-eks-cluster --region us-east-1 --approve

# 2. Download and create IAM policy
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

## Why Ingress over LoadBalancer?
| Feature | LoadBalancer Service | Ingress |
|---------|---------------------|---------|
| Cost | 1 ELB per service (~$18/month each) | 1 ALB for all services |
| Path routing | No | Yes (`/api`, `/web`) |
| Host routing | No | Yes (`api.example.com`) |
| SSL termination | Manual | Built-in |

## Cleanup
```bash
kubectl delete -f ingress.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
```
