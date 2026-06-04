# 03 - Deployment

## What is a Deployment?
A Deployment manages a set of identical Pods. It provides:
- **Self-healing** — restarts crashed pods automatically
- **Scaling** — run multiple replicas
- **Rolling updates** — zero-downtime deployments

This is the standard way to run stateless workloads in production.

## Files
- `deployment.yaml` - Deployment with 3 replicas of the Landmark Technology app
- `service.yaml` - LoadBalancer Service to expose the Deployment externally

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Verify
```bash
kubectl get deploy -n landmark
kubectl get pods -n landmark
kubectl get svc -n landmark
```

## Access the Application
```bash
kubectl get svc landmark-app-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Experiments
```bash
# Self-healing: delete a pod and watch it respawn
kubectl delete pod <pod-name> -n landmark
kubectl get pods -n landmark -w

# Scaling: scale up to 5 replicas
kubectl scale deployment landmark-deployment -n landmark --replicas=5
kubectl get pods -n landmark

# Rolling update: change the image
kubectl set image deployment/landmark-deployment nodejs=chafah/hilltop-nodejs-app:latest -n landmark
kubectl rollout status deployment/landmark-deployment -n landmark

# Rollback
kubectl rollout undo deployment/landmark-deployment -n landmark
```

## Prerequisites
- Namespace `landmark` must exist (step 01)
- AWS Load Balancer Controller installed (see 02-pod/README.md for installation)

## Cleanup
```bash
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
```
