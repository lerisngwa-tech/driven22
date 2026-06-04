# 02 - Pod

## What is a Pod?
A Pod is the smallest deployable unit in Kubernetes. It wraps one or more containers that share networking and storage. A standalone Pod has NO self-healing — if it dies, it stays dead.

## Files
- `pod.yaml` - A single Pod running the Landmark Technology Node.js app
- `service.yaml` - A LoadBalancer Service to expose the Pod externally

## How to Run
```bash
# Ensure namespace exists first
kubectl apply -f ../01-namespace/namespace.yaml

# Create the pod and service
kubectl apply -f pod.yaml
kubectl apply -f service.yaml
```

## Verify
```bash
kubectl get pods -n landmark
kubectl get svc -n landmark
```

## Access the Application
```bash
# Get the LoadBalancer external URL
kubectl get svc landmark-pod-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
Open the URL in your browser on port 80.

## Experiment
```bash
# Delete the pod and watch — it does NOT come back
kubectl delete pod landmark-pod -n landmark
kubectl get pods -n landmark
```
This demonstrates why we need Deployments (next step).

## Prerequisites
- Namespace `landmark` must exist (step 01)
- AWS Load Balancer Controller installed for the LoadBalancer service to provision an ELB

### Install AWS Load Balancer Controller
```bash
# 1. Create IAM OIDC provider
eksctl utils associate-iam-oidc-provider --cluster landmark-eks-cluster --region us-east-1 --approve

# 2. Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.1/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json

# 3. Create service account
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
```

## Cleanup
```bash
kubectl delete -f service.yaml
kubectl delete -f pod.yaml
```
