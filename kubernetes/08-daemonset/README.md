# 08 - DaemonSet

## What is a DaemonSet?
A DaemonSet ensures that a copy of a Pod runs on **every node** (or a subset of nodes) in the cluster. When nodes are added, pods are automatically scheduled on them. When nodes are removed, pods are garbage collected.

## Use Cases
- Log collection (Fluentd, Filebeat)
- Node monitoring (Prometheus Node Exporter, Datadog agent)
- Cluster networking (kube-proxy, Calico, AWS VPC CNI)
- Storage daemons (EBS CSI driver)

## Files
- `daemonset.yaml` - Fluentd DaemonSet that collects logs from every node

## How to Run
```bash
kubectl apply -f ../01-namespace/namespace.yaml
kubectl apply -f daemonset.yaml
```

## Verify
```bash
kubectl get daemonset -n landmark
kubectl get pods -n landmark -o wide -l app=landmark-logging

# You should see exactly 1 pod per node (we have 2 nodes = 2 pods)
kubectl get nodes
```

## Key Differences: DaemonSet vs Deployment
| Feature | Deployment | DaemonSet |
|---------|-----------|-----------|
| Replicas | You choose (e.g., 3) | 1 per node (automatic) |
| Scheduling | Anywhere | Every node |
| Scaling | Manual or HPA | Scales with cluster nodes |
| Use case | App workloads | Node-level agents |

## Experiments
```bash
# Check which node each pod is on
kubectl get pods -n landmark -l app=landmark-logging -o wide

# Check logs from the daemonset
kubectl logs -l app=landmark-logging -n landmark --tail=20
```

## Prerequisites
- Namespace `landmark` must exist (step 01)
- No additional controllers needed — DaemonSets are a core Kubernetes resource

## Cleanup
```bash
kubectl delete -f daemonset.yaml
```
