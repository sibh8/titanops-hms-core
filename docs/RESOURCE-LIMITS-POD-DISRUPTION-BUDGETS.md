# Resource Requests, Limits, and PodDisruptionBudgets (TITANOPS-126)

## Overview & Background
In containerized orchestrations, workloads without explicit resource requests and limits are prone to noisy-neighbor resource starvation, CPU throttling, and uncontrollable out-of-memory (OOM) killer terminations. Furthermore, without PodDisruptionBudgets (PDBs), voluntary cluster disruptions (e.g. node upgrades, spot terminations, cluster autoscaler drains) can terminate all replicas of a microservice simultaneously.

Under **TITANOPS-126**, bounded resource governance and high-availability eviction constraints are implemented across all 10 workloads.

---

## Architectural Implementation

### 1. Resource Allocations & Guarantees
Each service Deployment specifies both `requests` (for Kubernetes scheduler placement) and `limits` (for cgroups kernel enforcement):
- **Spring Boot Microservices (9 services)**:
  - CPU: `100m` request, `250m` limit.
  - Memory: `128Mi` request, `256Mi` limit.
- **Nginx React Frontend**:
  - CPU: `50m` request, `200m` limit.
  - Memory: `64Mi` request, `128Mi` limit.

### 2. High-Availability PodDisruptionBudgets (`k8s/pdb/`)
To guarantee that voluntary node drains (e.g. Kubernetes cluster version upgrades, Spot instance replacements) never take down a service:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <service-name>-pdb
  namespace: hms
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <service-name>
```
With 2 running replicas per service and `minAvailable: 1`, the Kubernetes eviction API guarantees that at least one healthy pod remains operational and serving user requests at all times during administrative drains.

---

## Automated Verification
Executed via `scripts/test-resource-limits-pdb.sh` (51/51 tests pass):
- Validation of CPU and memory requests and limits on all 10 Deployments.
- Syntax and `minAvailable: 1` constraint verification across all 10 PDB manifests.
- Simulation of single-node eviction constraints.
