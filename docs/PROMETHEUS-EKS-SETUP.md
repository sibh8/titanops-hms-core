# TitanOps HMS: Prometheus Installation & Configuration in EKS

## Overview
This document details the deployment, cluster role-based access control (RBAC), and node scrape configurations for Prometheus on Amazon EKS under ticket **TITANOPS-39**.

Prometheus serves as the primary time-series metrics collection and monitoring backend for the TitanOps Hospital Management System (HMS), scraping Kubernetes cluster infrastructure, container runtime metrics, and application performance metrics.

---

## Architecture Diagram

```
                                      KUBERNETES CLUSTER (EKS)
                   ─────────────────────────────────────────────────────────────
                   
  ┌───────────────────────────────────────────────────────────────────────────┐
  │                           monitoring Namespace                            │
  │                                                                           │
  │  ┌─────────────────────────────────────────────────────────────────────┐  │
  │  │                      Prometheus Server Pod                          │  │
  │  │  - Image: prom/prometheus:v2.51.2                                   │  │
  │  │  - Hardened: non-root UID 65534, capability drop                    │  │
  │  │  - Retention: 15 days TSDB storage                                  │  │
  │  │  - UI / API Port: 9090                                              │  │
  │  └──────────┬─────────────────┬───────────────────┬────────────────────┘  │
  │             │                 │                   │                       │
  └─────────────┼─────────────────┼───────────────────┼───────────────────────┘
                │                 │                   │
                ▼                 ▼                   ▼
     ┌──────────────────┐ ┌──────────────────┐ ┌───────────────────────────┐
     │ Kubelet Nodes    │ │ cAdvisor Metrics │ │ Kubernetes API Server     │
     │ (/metrics)       │ │ (/cadvisor)      │ │ (/metrics)                │
     └──────────────────┘ └──────────────────┘ └───────────────────────────┘
```

---

## 1. RBAC & Service Discovery Configuration
Prometheus runs under dedicated `ServiceAccount` `prometheus-k8s` bound to `ClusterRole` `prometheus-k8s`. This grants read-only access to discover and monitor cluster resources:
- `nodes`, `nodes/metrics`, `nodes/proxy`
- `pods`, `services`, `endpoints`
- `/metrics` and `/metrics/cadvisor` non-resource URLs

---

## 2. Configured Scrape Targets
Scrape definitions are codified in `k8s/monitoring/prometheus/02-prometheus-configmap.yaml` and `helm-values.yaml`:

| Target Job | Discovery Mechanism | Metrics Path | Purpose |
| :--- | :--- | :--- | :--- |
| `prometheus` | Static Config (`localhost:9090`) | `/metrics` | Prometheus internal query performance & memory. |
| `kubernetes-apiservers` | `kubernetes_sd_configs` (endpoints) | `/metrics` | API server request latencies, error codes, and admission rate. |
| `kubernetes-nodes` | `kubernetes_sd_configs` (node) | `/api/v1/nodes/${1}/proxy/metrics` | Kubelet runtime, volume mounts, and network throughput. |
| `kubernetes-cadvisor` | `kubernetes_sd_configs` (node) | `/api/v1/nodes/${1}/proxy/metrics/cadvisor` | Per-container CPU, Memory, and Network usage. |
| `kubernetes-service-endpoints` | `kubernetes_sd_configs` (endpoints) | Custom via annotation | Application microservices with `prometheus.io/scrape: "true"`. |

---

## 3. Storage as Code
Production Helm chart configuration is stored in `k8s/monitoring/prometheus/helm-values.yaml`, locking:
- Retention time: `15d`
- Retention size: `25Gi`
- NodeExporter and KubeStateMetrics enablement
- EBS gp3 storage class persistence

---

## 4. UI Access & Port Forwarding
To access the Prometheus web UI and graph query engine:
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```
Open your browser at `http://localhost:9090`.

---

## 5. Verification Test Suite

Run the automated verification suite:
```bash
./scripts/test-prometheus-eks.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: Prometheus EKS Deployment Verification (TITANOPS-39)         
==============================================================================

Phase 1: Manifest Integrity & Kustomize Build
  [PASS] 1. Prometheus manifests and Helm values files exist in repository
  [PASS] 2. Kustomize builds monitoring/prometheus bundle cleanly

Phase 2: RBAC & Security Hardening
  [PASS] 3. RBAC ClusterRole grants node, pod, endpoint, and metric scrape permissions
  [PASS] 4. Prometheus Deployment enforces non-root UID 65534 and dropped capabilities

Phase 3: Scrape Configuration & Target Discovery
  [PASS] 5. Prometheus ConfigMap defines node, kube-apiserver, and cAdvisor scrape jobs
  [PASS] 6. Prometheus Service exposes web UI and query endpoint on port 9090
  [PASS] 7. Scrape and operational configuration stored as code in helm-values.yaml

Phase 4: Architecture Documentation
  [PASS] 8. Prometheus deployment and architecture documentation exists

==============================================================================
   Summary: 8 Passed, 0 Failed
==============================================================================
All Prometheus EKS deployment tests passed successfully!
```
