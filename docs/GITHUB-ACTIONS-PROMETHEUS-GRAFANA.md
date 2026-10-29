# TitanOps HMS: GitHub Actions Telemetry in Prometheus and Grafana

## Overview
This document details the CI/CD pipeline health telemetry pipeline connecting GitHub Actions to Prometheus and Grafana for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-41**.

Because GitHub Actions lacks a native `/metrics` endpoint, pipeline telemetry is captured via a dual-channel ingestion topology:
1. **GitHub Actions Exporter**: Periodically polls the GitHub REST API (`/repos/sibh8/titanops-hms-core/actions/runs`) to expose Prometheus gauges and counters on port 9999.
2. **Prometheus Pushgateway**: Enables active workflow jobs to push instantaneous run statuses and execution durations directly into Prometheus on port 9091.

---

## Telemetry Pipeline Architecture

```
  ┌──────────────────────────────────────────────────────────────┐
  │                    GitHub Cloud Platform                     │
  │                                                              │
  │  ┌───────────────────────┐        ┌───────────────────────┐  │
  │  │ Workflow Runs         │        │ ci-health-metrics.yml │  │
  │  │ (PR / Push / Release) │        │ (Post-run telemetry)  │  │
  │  └───────────┬───────────┘        └───────────┬───────────┘  │
  └──────────────┼────────────────────────────────┼──────────────┘
                 │ GitHub REST API (Runs data)    │ Pushgateway POST (9091)
                 ▼                                ▼
  ┌──────────────────────────────────────────────────────────────┐
  │                   EKS monitoring Namespace                   │
  │                                                              │
  │  ┌───────────────────────────┐    ┌───────────────────────┐  │
  │  │ github-actions-exporter   │    │      Pushgateway      │  │
  │  │ (port 9999)               │    │      (port 9091)      │  │
  │  └─────────────┬─────────────┘    └───────────┬───────────┘  │
  │                │ Scraped every 15s            │ Scraped       │
  │                ▼                              ▼              │
  │  ┌────────────────────────────────────────────────────────┐  │
  │  │                   Prometheus Server                    │  │
  │  │  Metrics:                                              │  │
  │  │  - github_workflow_run_status (1=success, 0=failure)   │  │
  │  │  - github_workflow_run_duration_seconds                │  │
  │  │  - github_workflow_run_total                           │  │
  │  └────────────────────────────┬───────────────────────────┘  │
  │                               │                              │
  │                               ▼                              │
  │  ┌────────────────────────────────────────────────────────┐  │
  │  │                     Grafana UI                         │  │
  │  │  Dashboard: TitanOps HMS - GitHub Actions Health       │  │
  │  │  - Success Rate Gauge                                  │  │
  │  │  - Failed Runs 24h Stat & Table                        │  │
  │  │  - Duration Quantiles                                  │  │
  │  └────────────────────────────────────────────────────────┘  │
  └──────────────────────────────────────────────────────────────┘
```

---

## 1. Exposed Metrics Specification

| Metric Identifier | Type | Labels | Description |
| :--- | :--- | :--- | :--- |
| `github_workflow_run_status` | Gauge | `workflow`, `conclusion`, `run_id` | Status of workflow completion (`1` for success, `0` for failure). |
| `github_workflow_run_total` | Counter | `workflow`, `conclusion` | Cumulative counter of workflow completions partitioned by outcome. |
| `github_workflow_run_duration_seconds` | Gauge | `workflow` | Wall-clock execution time for workflow runs in seconds. |

---

## 2. Grafana Dashboard Panels & Failure Visibility

The `TitanOps HMS - GitHub Actions CI/CD Pipeline Health` dashboard (`titanops-github-actions`) provides immediate failure visibility:
- **Workflow Success Rate (%)**:
  $$\frac{\sum \text{github\_workflow\_run\_status}_{\text{success}}}{\sum \text{github\_workflow\_run\_status}_{\text{total}}} \times 100$$
- **Failed Workflow Runs (Last 24h)**: Stat panel colored bright red whenever failures $> 0$.
- **Recent Failed Workflow Runs Table**: Live tabular list filtering on `conclusion="failure"` showing workflow names, run IDs, and completion timestamps.

---

## 3. Verification Suite

Run the automated test runner:
```bash
./scripts/test-github-actions-monitoring.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: GitHub Actions Monitoring Verification (TITANOPS-41)         
==============================================================================

Phase 1: Metrics Exporter & Pushgateway Manifest Verification
  [PASS] 1. GitHub Actions exporter and Pushgateway manifests exist
  [PASS] 2. Kustomize builds ci-cd-exporter manifests cleanly

Phase 2: Prometheus Scrape Configuration for CI/CD Metrics
  [PASS] 3. Prometheus ConfigMap configures github-actions-exporter and pushgateway jobs
  [PASS] 4. Helm values file configures CI/CD scrape endpoints in additionalScrapeConfigs

Phase 3: Grafana Dashboard & Failure Visibility
  [PASS] 5. Grafana dashboard defines Success Rate gauge, run trends, and failed runs table
  [PASS] 6. Grafana ConfigMap 05-imported-dashboards-configmap.yaml includes CI/CD dashboard

Phase 4: GitHub Actions Workflow Integration & Documentation
  [PASS] 7. GitHub Actions telemetry workflow exports Prometheus metrics format
  [PASS] 8. Architecture and operational documentation exists

==============================================================================
   Summary: 8 Passed, 0 Failed
==============================================================================
All GitHub Actions monitoring integration tests passed successfully!
```
