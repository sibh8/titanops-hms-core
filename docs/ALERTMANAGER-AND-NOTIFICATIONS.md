# TitanOps HMS: Alertmanager & Operational Alerting Rules

## Overview
This document details the operational alerting topology, Alertmanager notification routing, and CI/CD failure notifications implemented for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-42**.

Alerting encompasses infrastructure pressure, container crashlooping, microservice 5xx errors, deployment rollout failures, and CI/CD workflow breakage, dispatching actionable alerts to on-call engineers via Slack and webhooks.

---

## Alert Routing Architecture

```
  ┌──────────────────────────────────────────────────────────────┐
  │                 Prometheus Server (monitoring)               │
  │                                                              │
  │  Operational Rules:                                          │
  │  - PodCrashLooping (restarts > 2 in 15m)                     │
  │  - MicroserviceHigh5xxErrorRate (> 5% errors)                │
  │  - KubernetesNodeMemoryPressure (avail < 10%)                │
  │  - FailedDeploymentRollout (unavailable replicas > 10m)      │
  └──────────────────────────────┬───────────────────────────────┘
                                 │ HTTP POST Alerts (port 9093)
                                 ▼
  ┌──────────────────────────────────────────────────────────────┐
  │                Alertmanager Server (monitoring)              │
  │                                                              │
  │  Routes & Grouping:                                          │
  │  - group_wait: 30s                                           │
  │  - group_interval: 5m                                        │
  │  - repeat_interval: 4h                                       │
  └──────────────┬───────────────────────────────┬───────────────┘
                 │ severity = critical           │ default / warning
                 ▼                               ▼
     ┌───────────────────────┐       ┌───────────────────────┐
     │ #titanops-critical    │       │ #titanops-alerts      │
     │ Incidents Channel     │       │ Standard Slack Alerts │
     └───────────────────────┘       └───────────────────────┘
```

---

## 1. Configured Alert Rules Specification

| Alert Name | PromQL Condition | Severity | Description |
| :--- | :--- | :--- | :--- |
| `PodCrashLooping` | `rate(kube_pod_container_status_restarts_total[15m]) * 60 > 2` | Critical | Identifies containers restarting continuously. |
| `MicroserviceHigh5xxErrorRate` | 5xx error rate $> 5\%$ of total traffic for 3m | Critical | Microservice failure or unhandled exception spike. |
| `KubernetesNodeMemoryPressure` | Node available memory $< 10\%$ for 5m | Warning | Physical memory exhaustion on EKS worker node. |
| `FailedDeploymentRollout` | Unavailable replicas $> 0$ for 10m | Critical | Failed Kubernetes rolling update or misconfigured image. |

---

## 2. Notification Channels & Routing
Alertmanager routes notifications to:
- `#titanops-alerts`: General operational notifications and warnings.
- `#titanops-critical-incidents`: P1/P0 incidents requiring immediate pager escalation.
- `security-webhook`: Ingests runtime security alerts into SIEM.

---

## 3. GitHub Actions Failure Step
Workflows across the repository are guarded with an automated post-step:
```yaml
- name: Dispatch Slack & Email Notification on CI/CD Failure
  if: failure() || github.event.workflow_run.conclusion == 'failure'
  run: |
    # Emits failure payload with commit, branch, and run URL
```

---

## 4. Verification Suite

Run the automated test runner:
```bash
./scripts/test-alertmanager-rules.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: Alertmanager & Operational Alerts (TITANOPS-42)              
==============================================================================

Phase 1: Alertmanager Manifest & Kustomize Validation
  [PASS] 1. Alertmanager manifests and kustomization exist
  [PASS] 2. Kustomize builds alertmanager bundle cleanly
  [PASS] 3. Alertmanager config defines notification routes for Slack and security webhook

Phase 2: Prometheus Operational Alerting Rules
  [PASS] 4. PrometheusRule defines PodCrashLooping, High 5xx, Node Pressure, and Rollout Failure
  [PASS] 5. Prometheus ConfigMap wires Alertmanager endpoint on port 9093

Phase 3: GitHub Actions Failure Notifications
  [PASS] 6. GitHub Actions workflow includes failure notification step with if: failure()

Phase 4: Architecture Documentation
  [PASS] 7. Alertmanager routing and notification documentation exists

==============================================================================
   Summary: 7 Passed, 0 Failed
==============================================================================
All Alertmanager & alerting rule tests passed successfully!
```
