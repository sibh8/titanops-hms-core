# TitanOps HMS: In-Cluster Prometheus Scrape Configuration

## Overview
This document details the ported Prometheus scrape configuration for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-74**.

The local `prometheus.yml` configuration historically used in `docker-compose.yml` has been ported and modernized into Kubernetes-native service discovery (`kubernetes_sd_configs`) and in-cluster DNS service targeting, enabling Prometheus to automatically discover, scrape, and monitor all 9 Spring Boot microservices and the OpenTelemetry Collector.

---

## Architecture Diagram

```
                                      KUBERNETES CLUSTER (EKS)
                   ─────────────────────────────────────────────────────────────
                   
  ┌───────────────────────────────────────────────────────────────┐
  │                    monitoring Namespace                       │
  │                                                               │
  │                 ┌───────────────────────────┐                 │
  │                 │     Prometheus Server     │                 │
  │                 │  (Scrapes every 15 secs)  │                 │
  │                 └─────────────┬─────────────┘                 │
  └───────────────────────────────┼───────────────────────────────┘
                                  │
                                  ▼
  ┌───────────────────────────────────────────────────────────────┐
  │                        hms Namespace                          │
  │                                                               │
  │    ┌──────────────────────────┐    ┌───────────────────────┐  │
  │    │ patient-service:8081     │    │ user-service:8082     │  │
  │    │ (/actuator/prometheus)   │    │ (/actuator/prometheus)│  │
  │    └──────────────────────────┘    └───────────────────────┘  │
  │    ┌──────────────────────────┐    ┌───────────────────────┐  │
  │    │ appointment-service:8083 │    │ provider-service:8084 │  │
  │    │ (/actuator/prometheus)   │    │ (/actuator/prometheus)│  │
  │    └──────────────────────────┘    └───────────────────────┘  │
  │    ┌──────────────────────────┐    ┌───────────────────────┐  │
  │    │ encounter-service:8085   │    │ billing-service:8086  │  │
  │    │ (/actuator/prometheus)   │    │ (/actuator/prometheus)│  │
  │    └──────────────────────────┘    └───────────────────────┘  │
  │    ┌──────────────────────────┐    ┌───────────────────────┐  │
  │    │ lab-service:8087         │    │ medication-svc:8088   │  │
  │    │ (/actuator/prometheus)   │    │ (/actuator/prometheus)│  │
  │    └──────────────────────────┘    └───────────────────────┘  │
  │    ┌──────────────────────────┐    ┌───────────────────────┐  │
  │    │ prescription-svc:8089    │    │ otel-collector:8889   │  │
  │    │ (/actuator/prometheus)   │    │ (/metrics)            │  │
  │    └──────────────────────────┘    └───────────────────────┘  │
  └───────────────────────────────────────────────────────────────┘
```

---

## 1. Dynamic Kubernetes Service Discovery
The in-cluster Prometheus server uses `role: endpoints` constrained to the `hms` namespace.

```yaml
- job_name: 'titanops-microservices-sd'
  kubernetes_sd_configs:
    - role: endpoints
      namespaces:
        names:
          - hms
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_name]
      action: keep
      regex: (patient|user|appointment|provider|encounter|billing|lab|medication|prescription)-service
    - source_labels: [__meta_kubernetes_endpoint_port_name]
      action: keep
      regex: http
    - target_label: __metrics_path__
      replacement: /actuator/prometheus
```

---

## 2. Ported Microservice Targets

| Service Name | In-Cluster Target | Metrics Path |
| :--- | :--- | :--- |
| `otel-collector` | `otel-collector.hms.svc.cluster.local:8889` | `/metrics` |
| `patient-service` | `patient-service.hms.svc.cluster.local:8081` | `/actuator/prometheus` |
| `user-service` | `user-service.hms.svc.cluster.local:8082` | `/actuator/prometheus` |
| `appointment-service` | `appointment-service.hms.svc.cluster.local:8083` | `/actuator/prometheus` |
| `provider-service` | `provider-service.hms.svc.cluster.local:8084` | `/actuator/prometheus` |
| `encounter-service` | `encounter-service.hms.svc.cluster.local:8085` | `/actuator/prometheus` |
| `billing-service` | `billing-service.hms.svc.cluster.local:8086` | `/actuator/prometheus` |
| `lab-service` | `lab-service.hms.svc.cluster.local:8087` | `/actuator/prometheus` |
| `medication-service` | `medication-service.hms.svc.cluster.local:8088` | `/actuator/prometheus` |
| `prescription-service` | `prescription-service.hms.svc.cluster.local:8089` | `/actuator/prometheus` |

---

## 3. Microservice Manifest Annotations
All microservice Kubernetes service manifests in `k8s/deployments/` have been annotated with:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/actuator/prometheus"
  prometheus.io/port: "<port>"
```

---

## 4. Verification Suite

Run the automated test runner:
```bash
./scripts/test-prometheus-scrape-microservices.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: Prometheus Microservices Scrape Verification (TITANOPS-74)   
==============================================================================

Phase 1: Dynamic Kubernetes Service Discovery Verification
  [PASS] 1. Prometheus ConfigMap defines dynamic SD job for microservices in hms namespace
  [PASS] 2. Service discovery relabels metrics_path to /actuator/prometheus

Phase 2: Ported Scrape Jobs for All 9 Services & OTel Collector
  [PASS] 3. Ported scrape config includes all 9 microservices with in-cluster DNS
  [PASS] 4. Ported scrape config includes otel-collector metrics target on port 8889

Phase 3: Microservice Service Manifest Annotations
  [PASS] 5. All 9 microservices annotated with prometheus.io/scrape and /actuator/prometheus

Phase 4: Helm Values & Architecture Documentation
  [PASS] 6. Production helm-values.yaml configures additionalScrapeConfigs for SD
  [PASS] 7. Architecture documentation exists detailing ported scrape configs

==============================================================================
   Summary: 7 Passed, 0 Failed
==============================================================================
All Prometheus scrape config porting tests passed successfully!
```
