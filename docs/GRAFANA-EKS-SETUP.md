# TitanOps HMS: Grafana Dashboards for App Performance & Cluster Health

## Overview
This document details the Grafana deployment and operational dashboards in Amazon EKS for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-40**.

Grafana is provisioned as an in-cluster visualization service connected to the in-cluster Prometheus time-series backend, serving operational dashboards for microservice performance and node/cluster resource health.

---

## Architecture Diagram

```
                                      KUBERNETES CLUSTER (EKS)
                   ─────────────────────────────────────────────────────────────
                   
  ┌───────────────────────────────────────────────────────────────┐
  │                    monitoring Namespace                       │
  │                                                               │
  │    ┌───────────────────────────┐                              │
  │    │     Prometheus Server     │                              │
  │    │      (port: 9090)         │                              │
  │    └─────────────┬─────────────┘                              │
  │                  │ HTTP Queries (port 9090)                   │
  │                  ▼                                            │
  │    ┌───────────────────────────┐                              │
  │    │      Grafana Server       │                              │
  │    │   - Port 3000 (HTTP)      │                              │
  │    │   - Hardened: UID 472     │                              │
  │    │   - Auto-provisioned DS   │                              │
  │    └─────────────┬─────────────┘                              │
  └──────────────────┼────────────────────────────────────────────┘
                     │
                     ▼
          ┌─────────────────────┐
          │ Site Reliability    │
          │ Engineer Dashboard  │
          │ (localhost:3000)    │
          └─────────────────────┘
```

---

## 1. Automated Datasource Provisioning
Grafana automatically initializes with an immutable Prometheus data source via ConfigMap `grafana-datasources` mounted at `/etc/grafana/provisioning/datasources`:
- **Datasource Name**: `Prometheus`
- **URL**: `http://prometheus.monitoring.svc.cluster.local:9090`
- **Access**: `proxy`
- **Default**: `true`

---

## 2. Included Core Dashboards

### A. Application Performance Dashboard (`titanops-app-perf`)
- **Request Rate (req/s)**: `sum(rate(http_server_requests_seconds_count[1m])) by (service)`
- **p95 Latency**: `histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le, service))`
- **5xx Error Rate**: `sum(rate(http_server_requests_seconds_count{status=~"5.."}[1m])) by (service)`

### B. Node & Cluster Resource Health Dashboard (`titanops-cluster-health`)
- **Node CPU Utilization (%)**: `(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100`
- **Node Memory Usage (%)**: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`
- **Pod Restarts**: `sum(increase(kube_pod_container_status_restarts_total[1h])) by (namespace, pod)`

---

## 3. Access & Port Forwarding
To access the Grafana UI locally:
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```
Open your browser at `http://localhost:3000` and log in with default credentials (`admin` / `TitanOpsAdmin2026!`).

---

## 4. Verification Suite

Execute the automated test suite:
```bash
./scripts/test-grafana-eks.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: Grafana EKS Deployment Verification (TITANOPS-40)            
==============================================================================

Phase 1: Manifest Integrity & Kustomize Build
  [PASS] 1. Grafana manifests and dashboard files exist in k8s/monitoring/grafana
  [PASS] 2. Kustomize builds monitoring/grafana bundle cleanly

Phase 2: Prometheus Datasource Connection & Hardening
  [PASS] 3. Datasource ConfigMap connects to in-cluster Prometheus service
  [PASS] 4. Grafana deployment enforces non-root UID 472 and dropped capabilities
  [PASS] 5. Grafana Service exposes HTTP port 3000

Phase 3: Application Performance & Resource Health Dashboards
  [PASS] 6. Application Performance dashboard defines latency, error rate, and request metrics
  [PASS] 7. Node and Cluster Resource Health dashboard defines CPU, memory, and restart panels

Phase 4: Architecture Documentation
  [PASS] 8. Grafana setup and dashboard architecture documentation exists

==============================================================================
   Summary: 8 Passed, 0 Failed
==============================================================================
All Grafana EKS deployment and dashboard tests passed successfully!
```
