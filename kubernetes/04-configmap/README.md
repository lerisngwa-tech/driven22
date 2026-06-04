# 04 - ConfigMap

## What is a ConfigMap?
A ConfigMap stores non-sensitive configuration data as key-value pairs. It decouples configuration from container images, so you can change config without rebuilding images.

## Files
- `configmap.yaml` - ConfigMap with APP_NAME, NODE_ENV, PORT
- `deployment.yaml` - Deployment that injects ConfigMap values as environment variables via `envFrom`
- `service.yaml` - LoadBalancer Service to expose the app

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## Verify
```bash
kubectl get configmap -n landmark
kubectl describe configmap landmark-config -n landmark

# Check env vars inside a pod
kubectl exec -it $(kubectl get pods -n landmark -l app=landmark-config-app -o jsonpath='{.items[0].metadata.name}') -n landmark -- env | grep -E "APP_NAME|NODE_ENV|PORT"
```

## Access the Application
```bash
kubectl get svc landmark-config-service -n landmark -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Experiments
```bash
# Update the configmap
kubectl edit configmap landmark-config -n landmark

# Restart pods to pick up new values (envFrom requires pod restart)
kubectl rollout restart deployment landmark-configmap-demo -n landmark
```

## Prerequisites
- Namespace `landmark` must exist (step 01)
- AWS Load Balancer Controller installed (see 02-pod/README.md)

## Cleanup
```bash
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f configmap.yaml
```
