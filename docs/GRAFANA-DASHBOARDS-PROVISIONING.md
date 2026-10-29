# TitanOps HMS: Imported Grafana Dashboards via Provisioning ConfigMaps

## Overview
This document details the configuration and deployment of pre-built Grafana dashboards into the Amazon EKS cluster for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-75**.

Rather than rebuilding dashboards from scratch, the 4 production dashboards pre-existing in the repository have been packaged directly into Kubernetes ConfigMaps and auto-mounted into Grafana via its declarative provisioning provider engine.

---

## Imported Dashboards Architecture

```
  ┌────────────────────────────────────────────────────────────────────────┐
  │                           Git Repository                               │
  │                                                                        │
  │  grafana/dashboards/                                                   │
  │  ├── business-metrics.json  (Revenue, active encounters, patients)    │
  │  ├── functional.json        (Microservice API endpoints & HTTP status) │
  │  ├── medicore-hms.json      (Full-stack HMS end-to-end telemetry)      │
  │  └── operational.json       (JVM heap, GC pauses, thread counts)       │
  └───────────────────────────────────┬────────────────────────────────────┘
                                      │ Ingested as Kubernetes ConfigMap
                                      ▼
  ┌────────────────────────────────────────────────────────────────────────┐
  │                      EKS monitoring Namespace                          │
  │                                                                        │
  │  ConfigMap: grafana-dashboards-imported                                │
  │  └── Mounted to: /etc/grafana/dashboards                               │
  │                                                                        │
  │  ConfigMap: grafana-dashboard-providers                                │
  │  └── Mounted to: /etc/grafana/provisioning/dashboards/provider.yaml    │
  │                                                                        │
  │  ┌──────────────────────────────────────────────────────────────────┐  │
  │  │                       Grafana Pod                                │  │
  │  │  - Automatically discovers all 4 JSON dashboards                │  │
  │  │  - Queries in-cluster Prometheus (prometheus:9090)               │  │
  │  │  - Live data population without manual UI import                 │  │
  │  └──────────────────────────────────────────────────────────────────┘  │
  └────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Description of Imported Dashboards

| Dashboard File | Target Scope | Key Panels & Queries |
| :--- | :--- | :--- |
| `business-metrics.json` | Hospital Business Health | Patient admissions count, billing transaction volume, completed encounters, pharmacy prescription fulfillment. |
| `functional.json` | API Endpoint Operations | Microservice response status distribution (2xx/4xx/5xx), per-route latency distributions, user auth success/failure. |
| `medicore-hms.json` | Cross-Service HMS Health | Full system request rate, end-to-end transaction latency, service-to-service communication errors. |
| `operational.json` | JVM & Infrastructure Runtime | JVM Heap usage (`jvm_memory_used_bytes`), GC pause times, database connection pool saturation (HikariCP). |

---

## 2. In-Cluster Declarative Provisioning Configuration

### Dashboard Provider (`provider.yaml`)
```yaml
apiVersion: 1
providers:
  - name: 'MediCore HMS Dashboards'
    orgId: 1
    folder: 'MediCore HMS'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards
      foldersFromFilesStructure: false
```

### In-Cluster Datasource (`datasource.yml`)
```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus.monitoring.svc.cluster.local:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
```

---

## 3. Verification Suite

Run the automated test runner:
```bash
./scripts/test-grafana-dashboards-provisioning.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: Grafana Dashboards Provisioning Verification (TITANOPS-75)   
==============================================================================

Phase 1: Existing Repository Dashboard Assets Integrity
  [PASS] 1. All 4 original repository dashboards exist and are non-empty

Phase 2: Kubernetes ConfigMap Dashboard Ingestion
  [PASS] 2. ConfigMap 05-imported-dashboards-configmap.yaml packages all 4 dashboards
  [PASS] 3. Grafana deployment mounts imported dashboards at /etc/grafana/dashboards
  [PASS] 4. Dashboard provider configuration registers /etc/grafana/dashboards

Phase 3: In-Cluster Prometheus Datasource Verification
  [PASS] 5. In-cluster datasource points to internal Prometheus service FQDN
  [PASS] 6. Kustomize builds Grafana monitoring suite cleanly

Phase 4: Architecture Documentation
  [PASS] 7. Documentation exists detailing imported dashboards and provisioning

==============================================================================
   Summary: 7 Passed, 0 Failed
==============================================================================
All Grafana dashboard importing tests passed successfully!
```
