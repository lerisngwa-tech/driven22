# 07 - HorizontalPodAutoscaler (HPA)

## What is an HPA?
A HorizontalPodAutoscaler automatically scales the number of pods in a Deployment based on observed metrics (CPU, memory, or custom metrics). It scales up under load and scales down when idle.

## Files
- `hpa.yaml` - HPA targeting 70% CPU, scaling between 2-6 replicas
- `deployment.yaml` - Deployment with resource requests (required for HPA)
- `service.yaml` - LoadBalancer Service to expose the app

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f ../04-configmap/configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml
```

## Verify
```bash
kubectl get hpa -n landmark
kubectl describe hpa landmark-hpa -n landmark

# Watch scaling in real-time
kubectl get hpa -n landmark -w
```

## Access the Application
```bash
kubectl get svc landmark-hpa-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Experiment - Generate Load
```bash
# Run a load generator pod
kubectl run load-gen --image=busybox -n landmark -- /bin/sh -c \
  "while true; do wget -q -O- http://landmark-hpa-service.landmark; done"

# Watch the HPA scale up
kubectl get hpa -n landmark -w

# Stop the load
kubectl delete pod load-gen -n landmark

# Watch it scale back down (takes ~5 minutes)
kubectl get hpa -n landmark -w
```

## Prerequisites
- Namespace `landmark` must exist (step 01)
- ConfigMap from step 04 must exist
- AWS Load Balancer Controller installed (see 02-pod/README.md)
- **Deployment MUST have resource requests** defined (HPA needs this to calculate utilization)

### Metrics Server (REQUIRED)
HPA needs metrics-server to read CPU/memory usage:
```bash
# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify it's running
kubectl get deployment metrics-server -n kube-system

# Test metrics
kubectl top nodes
kubectl top pods -n landmark
```

## Cleanup
```bash
kubectl delete -f hpa.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
```
