# TitanOps HMS: OpenTelemetry Collector and Jaeger Tracing

## Overview
This document details the distributed tracing architecture deployed in Amazon EKS for the **TitanOps Hospital Management System (HMS)** under ticket **TITANOPS-66**.

Distributed tracing provides full request-lifecycle observability across the HMS microservice architecture, allowing DevOps and application engineers to measure inter-service latencies, detect bottleneck database queries, trace transaction propagation across microservices, and troubleshoot errors.

---

## Distributed Tracing Pipeline

```
                                      KUBERNETES CLUSTER (EKS)
                   ─────────────────────────────────────────────────────────────
                   
  ┌───────────────────────────────────────────────────────────────┐
  │                    HMS Microservices (hms)                    │
  │                                                               │
  │  ┌────────────────────┐            ┌───────────────────────┐  │
  │  │  patient-service   │            │  appointment-service  │  │
  │  │ (OTel Java Agent)  │            │  (OTel Java Agent)    │  │
  │  └─────────┬──────────┘            └───────────┬───────────┘  │
  │            │ OTLP/gRPC (4317)                  │ OTLP/gRPC    │
  │            ▼                                   ▼              │
  │      ┌───────────────────────────────────────────────┐        │
  │      │     OpenTelemetry Collector (hms)             │        │
  │      │  - Receives OTLP (4317 gRPC, 4318 HTTP)       │        │
  │      │  - Batch Processor (256 spans / 5s)           │        │
  │      │  - Exporters: Prometheus (8889), OTLP/Jaeger  │        │
  │      └───────────────────────┬───────────────────────┘        │
  │                              │ OTLP gRPC (4317)               │
  │                              ▼                                │
  │      ┌───────────────────────────────────────────────┐        │
  │      │           Jaeger All-in-One (hms)             │        │
  │      │  - In-Memory Spans Storage (100k traces)      │        │
  │      │  - Jaeger Query UI (port 16686)               │        │
  │      └───────────────────────┬───────────────────────┘        │
  └──────────────────────────────┼────────────────────────────────┘
                                 │
                                 ▼
                     ┌───────────────────────┐
                     │ Developer / DevOps    │
                     │ Jaeger Web UI (16686) │
                     └───────────────────────┘
```

---

## 1. Microservice Instrumentation
Each microservice container image packages the OpenTelemetry Java Auto-Instrumentation Agent (`opentelemetry-javaagent.jar`). At runtime, standard environment variables configure telemetry export:
- `OTEL_EXPORTER_OTLP_ENDPOINT`: `http://otel-collector:4317`
- `OTEL_SERVICE_NAME`: Service identifier (e.g., `patient-service`, `appointment-service`, `billing-service`)
- `OTEL_TRACES_EXPORTER`: `otlp`

All microservices use W3C Trace Context propagation headers (`traceparent`, `tracestate`) across HTTP calls, ensuring downstream calls inherit parent trace IDs.

---

## 2. In-Cluster OpenTelemetry Collector Configuration
The OpenTelemetry Collector is deployed as a Kubernetes Deployment running the official hardened image (`otel/opentelemetry-collector:0.100.0`):
- **Receivers**:
  - `otlp/grpc`: Listening on `0.0.0.0:4317`
  - `otlp/http`: Listening on `0.0.0.0:4318`
- **Processors**:
  - `batch`: Buffers up to 256 spans or 5 seconds before emitting to reduce network overhead.
- **Exporters**:
  - `otlp/jaeger`: Emits traces over gRPC to `jaeger:4317`.
  - `prometheus`: Scraped on port `8889` for collector pipeline health metrics.
  - `debug`: Detailed logging of span throughput in development environments.

---

## 3. Jaeger In-Cluster Deployment
Jaeger is deployed via the lightweight `jaegertracing/all-in-one:1.57.0` container:
- Native OTLP ingestion enabled via `COLLECTOR_OTLP_ENABLED=true`.
- In-memory ring buffer storage sized for 100,000 active spans.
- Query engine serving the web UI on port `16686`.

To access the Jaeger UI locally:
```bash
kubectl port-forward svc/jaeger 16686:16686 -n hms
```
Navigate to `http://localhost:16686` to search traces by service, operation, tags, or duration.

---

## 4. Network Policy & Security Hardening
- **RBAC & Security**: Pods run with non-root UID `10001`, dropped Linux capabilities (`drop: [ALL]`), and read-only root filesystems where applicable.
- **Network Isolation**: `observability-network-policy` allows inbound TCP port `4317` exclusively from registered HMS microservices, preventing unauthorized cluster pods from flooding telemetry buffers.

---

## 5. Verification Suite

Execute the automated test suite:
```bash
./scripts/test-otel-jaeger-eks.sh
```

Expected test output:
```
==============================================================================
   TitanOps HMS: OTel Collector & Jaeger Verification (TITANOPS-66)           
==============================================================================

Phase 1: Kubernetes Manifests & Kustomize Validation
  [PASS] 1. Observability k8s directory and manifests exist
  [PASS] 2. Kustomize validation completes without errors

Phase 2: OpenTelemetry Collector Configuration & Hardening
  [PASS] 3. OTel Collector ConfigMap defines OTLP receivers, Jaeger exporter, and pipelines
  [PASS] 4. OTel Collector deployment runs hardened (non-root UID 10001, drop ALL)
  [PASS] 5. OTel Collector service exposes gRPC 4317, HTTP 4318, and metrics 8889

Phase 3: Jaeger In-Cluster Distributed Tracing
  [PASS] 6. Jaeger deployment configured with OTLP ingestion and memory storage
  [PASS] 7. Jaeger service exposes UI (16686) and OTLP receivers

Phase 4: Microservice Instrumentation & Network Policy Compliance
  [PASS] 8. Microservices route traces to in-cluster otel-collector service
  [PASS] 9. Observability NetworkPolicy allows ingress on port 4317 from backend services

Phase 5: Trace Propagation & Documentation Verification
  [PASS] 10. Distributed tracing and OTel architecture documentation exists

==============================================================================
   Summary: 10 Passed, 0 Failed
==============================================================================
All OpenTelemetry Collector & Jaeger tests passed successfully!
```
