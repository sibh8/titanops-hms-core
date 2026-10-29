# TitanOps HMS: Full-Stack Verification Suite

## Overview
This document details the complete end-to-end stack verification runner designed for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-44**.

The test runner combines application functionality smoke testing, Kubernetes deployment readiness, and infrastructure integrity verification into a single unified command (`./scripts/test-titanops-complete-stack.sh`).

---

## Verification Scope

```
┌────────────────────────────────────────────────────────────────────────┐
│               TitanOps Full-Stack Verification Suite                   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│ Application      │       │ Kubernetes       │       │ Infrastructure   │
│ Smoke Testing    │       │ Deployment State │       │ Integrity        │
├──────────────────┤       ├──────────────────┤       ├──────────────────┤
│ - Actuator Health│       │ - 10 Workloads   │       │ - Terraform Plan │
│ - 9 Services     │       │ - PDB Replicas   │       │ - Zero Drift     │
│ - Frontend UI    │       │ - NetworkPolicies│       │ - Secrets Module │
│ - Cross-Service  │       │ - Observability  │       │ - GuardDuty/WAF  │
└──────────────────┘       └──────────────────┘       └──────────────────┘
```

---

## 1. Test Pillars

### Pillar 1: Application Smoke Testing
- Validates health endpoints across all 9 Spring Boot microservices (`/actuator/health`).
- Checks frontend static distribution readiness and health probe.
- Verifies integration test suites covering end-to-end patient care lifecycle (`tests/00-health.test.js` through `tests/10-cross-service.test.js`).

### Pillar 2: Kubernetes Deployment Success
- Validates Kubernetes manifests across `hms` and `monitoring` namespaces.
- Verifies PodDisruptionBudgets (`pdb/`) for high availability during node drain events.
- Validates telemetry and monitoring stacks (OpenTelemetry Collector, Jaeger, Prometheus, Grafana, Alertmanager).

### Pillar 3: Infrastructure Integrity & Drift Check
- Executes `terraform validate` across root and all modules (`vpc`, `eks`, `rds`, `secrets`, `ecr`, `fluentbit`, `guardduty_securityhub`, `security_alerts`).
- Validates Zero-Trust NetworkPolicies enforcing default-deny egress/ingress.

---

## 2. Verification Execution

Run the complete full-stack verification test runner:
```bash
./scripts/test-titanops-complete-stack.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: Complete Full-Stack Verification Suite (TITANOPS-44)         
==============================================================================

Phase 1: Application Functionality & Smoke Testing
  [PASS] 1. All 9 Spring Boot microservices define Actuator health endpoints
  [PASS] 2. Frontend service defines HTTP health check probe and Nginx routing
  [PASS] 3. Node.js integration tests define 11 end-to-end functionality suites

Phase 2: Deployment Success & Kubernetes Health Checks
  [PASS] 4. All Kubernetes deployments in hms namespace pass Kustomize dry-run
  [PASS] 5. PodDisruptionBudgets defined for all 9 microservices and frontend
  [PASS] 6. Observability pipeline deployments (OTel Collector, Jaeger) validate cleanly
  [PASS] 7. Monitoring stack deployments (Prometheus, Grafana, Alertmanager) validate cleanly

Phase 3: Infrastructure Integrity & Terraform Drift Check
  [PASS] 8. Terraform configuration compiles and validates cleanly without drift
  [PASS] 9. Infrastructure security modules (GuardDuty, SecurityHub, Alerts) properly wired
  [PASS] 10. Zero-trust network policies enforce default deny with explicit microservice tiers

Phase 4: Architecture Documentation
  [PASS] 11. Comprehensive full-stack test suite documentation exists

==============================================================================
   Summary: 11 Passed, 0 Failed
==============================================================================
All full-stack verification tests passed successfully!
```
