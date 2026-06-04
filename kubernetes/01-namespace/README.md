# 01 - Namespace

## What is a Namespace?
A Namespace is a virtual cluster within a Kubernetes cluster. It provides isolation for resources, allowing multiple teams or projects to share the same cluster without interfering with each other.

## Files
- `namespace.yaml` - Creates the `landmark` namespace

## How to Run
```bash
kubectl apply -f namespace.yaml
```

## Verify
```bash
kubectl get namespaces
kubectl get ns landmark
```

## Prerequisites
- A running Kubernetes cluster (EKS)
- kubectl configured (`aws eks update-kubeconfig --region us-east-1 --name landmark-eks-cluster`)

## Cleanup
```bash
kubectl delete -f namespace.yaml
```
> ⚠️ Deleting a namespace removes ALL resources inside it.
