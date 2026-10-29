# TitanOps HMS: Security Event Alerting

## Overview
This document details the multi-tiered security event alerting architecture implemented for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-134**. 

Security monitoring covers runtime threat intelligence, web perimeter filtering, and authentication anomalies, automatically funneling actionable security incidents to on-call security and DevOps teams.

---

## Architecture Diagram

```
                     ┌───────────────────────┐
                     │    AWS GuardDuty      │
                     │  (EKS Runtime Audit)  │
                     └──────────┬────────────┘
                                │ High/Critical Findings (>= 7.0)
                                ▼
                     ┌───────────────────────┐
                     │    AWS EventBridge    │
                     └──────────┬────────────┘
                                │
                                ▼
┌─────────────────────┐   ┌─────────────────────────┐   ┌───────────────────────┐
│ CloudWatch Alarm:   ├──▶│       AWS SNS           │◀──┤ CloudWatch Alarm:     │
│ 401/403 Auth Spikes │   │ security-alerts-topic   │   │ WAF Block Rate Spikes │
└─────────────────────┘   └───────────┬─────────────┘   └───────────────────────┘
                                      │
                   ┌──────────────────┴──────────────────┐
                   ▼                                     ▼
          ┌───────────────────┐                 ┌──────────────────┐
          │ DevOps PagerDuty  │                 │ Security Webhook │
          │ & Slack Incident  │                 │ / SIEM Ingestion │
          └───────────────────┘                 └──────────────────┘
```

---

## 1. AWS EventBridge & GuardDuty Alerting

AWS EventBridge captures Amazon GuardDuty findings in real time. Findings with a severity rating $\ge 7.0$ (High to Critical) trigger an EventBridge rule that immediately dispatches an alert payload to the `security-alerts` SNS topic.

### Event Pattern
```json
{
  "source": ["aws.guardduty"],
  "detail-type": ["GuardDuty Finding"],
  "detail": {
    "severity": [
      7, 7.0, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9,
      8, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9
    ]
  }
}
```

### Addressed Threat Classes
- **EKS Compromised Service Account**: `UnauthorizedAccess:EC2/TorIPCaller`, `CredentialAccess:K8s/AnomalousCall`
- **Crypto-Mining Activity**: `CryptoCurrency:Runtime/ContainerExecution`
- **Privilege Escalation**: `PrivilegeEscalation:Runtime/DockerSocketMounted`

---

## 2. Perimeter & Authentication Anomaly Alarms (CloudWatch)

### A. Authentication Failure Spike (`HTTPCode_Target_4XX_Count`)
- **Metric**: `AWS/ApplicationELB` `HTTPCode_Target_4XX_Count`
- **Threshold**: $> 50$ 4XX responses over two consecutive 5-minute evaluation periods.
- **Purpose**: Rapid detection of credential stuffing attacks, brute-force login attempts against `/api/v1/auth/login`, and malicious scanner directory enumeration.
- **Action**: Publishes incident to SNS `security-alerts`.

### B. AWS WAF Block Rate Spike (`BlockedRequests`)
- **Metric**: `AWS/WAFV2` `BlockedRequests`
- **Threshold**: $> 100$ blocked requests in a 5-minute period.
- **Purpose**: Detects automated vulnerability probing (SQL Injection payloads, cross-site scripting vectors, automated bot scans).

---

## 3. In-Cluster Kubernetes Prometheus Alerts

The `PrometheusRule` defined in `k8s/monitoring/security-alerting-rules.yaml` adds deep runtime and cluster-level security alerts:

| Alert Name | Condition | Severity | Description |
| :--- | :--- | :--- | :--- |
| `HighAuthFailureRate` | Rate of 401/403 $> 5\text{ req/s}$ | Critical | Ingress-level authentication rejection spike. |
| `WAFBlockRateSpike` | Rate of WAF blocks $> 10\text{ req/s}$ | High | Mass perimeter filtering engagement. |
| `ContainerRunningAsRoot` | Running pod with UID 0 in `titanops-*` namespaces | High | Violation of non-root container security posture. |
| `ExcessiveKubeApiDeniedRequests` | API server 403 rate $> 2\text{ req/s}$ | Warning | Potential unauthorized cluster reconnaissance. |

---

## 4. Verification

Run the verification test suite:
```bash
./scripts/test-security-event-alerting.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: Security Event Alerting Verification (TITANOPS-134)          
==============================================================================

Phase 1: Terraform Infrastructure & Event Routing Verification
  [PASS] 1. Terraform configuration with security alerts module validates cleanly
  [PASS] 2. SNS topic resource created for centralized security notifications
  [PASS] 3. EventBridge rule captures High and Critical GuardDuty security findings (severity >= 7.0)
  [PASS] 4. EventBridge target forwards GuardDuty findings directly to security SNS topic
  [PASS] 5. CloudWatch metric alarm monitors HTTP 401/403 authentication failure spikes
  [PASS] 6. CloudWatch metric alarm monitors AWS WAF blocked request spikes
  [PASS] 7. Root Terraform main.tf and outputs.tf expose security alert outputs

Phase 2: In-Cluster Prometheus & Runtime Security Alerting
  [PASS] 8. Kubernetes PrometheusRule file exists and defines valid security alert rules

Phase 3: Security Alerting Architecture Documentation
  [PASS] 9. Security alerting architecture and incident runbook documentation exists

==============================================================================
   Summary: 9 Passed, 0 Failed
==============================================================================
All security event alerting tests passed successfully!
```
