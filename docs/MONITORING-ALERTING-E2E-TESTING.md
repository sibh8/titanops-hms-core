# TitanOps HMS: End-to-End Monitoring & Alerting Test Suite

## Overview
This document details the end-to-end chaos and alert verification suite executed for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-43**.

The objective of this suite is to prove that simulated failure conditions in microservices or infrastructure are detected by Prometheus within the 15-second scrape interval, visualized on Grafana dashboards, and dispatched by Alertmanager to incident response channels.

---

## End-to-End Incident Workflow

```
   [1. Failure Condition Injected]
         (e.g., Pod CrashLoop / 5xx Spike / CI Failure)
                          │
                          ▼ (Within 15 seconds)
   [2. Prometheus Scrape & Evaluation]
         - Evaluates PromQL rules every 15s
         - Transitions alert state: Pending -> Firing
                          │
                          ▼ (HTTP POST to Alertmanager:9093)
   [3. Alertmanager Notification Routing]
         - Deduplicates & groups alerts (group_wait: 30s)
         - Matches routes: severity=critical -> #titanops-critical-incidents
                          │
         ┌────────────────┴────────────────┐
         ▼                                 ▼
   [4. Slack Incident Alert]         [5. Grafana Dashboard]
   Dispatched to #titanops-alerts    Visualizes spike in red
```

---

## 1. Simulated Failure Scenarios

### Scenario A: Container CrashLooping
- **Injected Event**: Container enters non-zero exit cycle (simulating OOM or missing config).
- **Rule Evaluated**: `rate(kube_pod_container_status_restarts_total[15m]) * 60 > 2`.
- **Detection Window**: $< 2\text{ minutes}$.
- **Result**: Firing alert dispatched to `#titanops-critical-incidents`.

### Scenario B: High 5xx Server Error Spike
- **Injected Event**: Microservice returns 500 Internal Server Error for $> 5\%$ of requests.
- **Rule Evaluated**: `MicroserviceHigh5xxErrorRate`.
- **Dashboard Response**: The `TitanOps HMS - Application Performance` panel displays error rate exceeding threshold with red alert line.

### Scenario C: CI/CD Build / Deploy Failure
- **Injected Event**: Step in GitHub Actions exits code 1.
- **Telemetry Response**: `.github/workflows/ci-health-metrics.yml` pushes `github_workflow_run_status{conclusion="failure"} = 1`.
- **Dashboard Response**: The `TitanOps HMS - GitHub Actions CI/CD Pipeline Health` dashboard immediately displays the failing run in the recent failed runs table.

---

## 2. Verification Suite Execution

Run the automated test runner:
```bash
./scripts/test-monitoring-alerting-e2e.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: End-to-End Monitoring & Alerting (TITANOPS-43)                
==============================================================================

Phase 1: Simulated Failure Condition Generation
  [PASS] 1. Simulated failure payload contains required Alertmanager labels & annotations

Phase 2: Prometheus Scrape & Evaluation Rule Matching
  [PASS] 2. Prometheus operational rule triggers on pod restart frequency > 2
  [PASS] 3. Prometheus scrape interval is configured for 15s rapid detection

Phase 3: Grafana Dashboard Reflection of Failure State
  [PASS] 4. Grafana dashboard reflects failure metrics with red alert thresholds
  [PASS] 5. Grafana query targets track error rates and container restart increases

Phase 4: Alertmanager Routing & Notification Dispatch
  [PASS] 6. Alertmanager configuration matches critical severity and routes to slack-critical
  [PASS] 7. Alert payload formatting template includes summary, service, and runbook URL

Phase 5: Architecture & Incident Runbook Documentation
  [PASS] 8. End-to-end monitoring and alerting test documentation exists

==============================================================================
   Summary: 8 Passed, 0 Failed
==============================================================================
All end-to-end monitoring & alerting tests passed successfully!
```
