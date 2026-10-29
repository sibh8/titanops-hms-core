#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: OpenTelemetry Collector & Jaeger EKS Tracing Verification Suite
# Ticket: TITANOPS-66: Deploy OpenTelemetry Collector + Jaeger in EKS
# ==============================================================================
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   TitanOps HMS: OTel Collector & Jaeger Verification (TITANOPS-66)           ${NC}"
echo -e "${BLUE}==============================================================================${NC}\n"

check() {
    local test_name="$1"
    local condition="$2"
    if eval "$condition"; then
        echo -e "  [${GREEN}PASS${NC}] ${test_name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  [${RED}FAIL${NC}] ${test_name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OBS_DIR="${REPO_DIR}/k8s/observability"
DEPLOY_DIR="${REPO_DIR}/k8s/deployments"
NP_FILE="${REPO_DIR}/k8s/network-policies/05-observability-network-policy.yaml"
DOC_FILE="${REPO_DIR}/docs/OTEL-JAEGER-DISTRIBUTED-TRACING.md"

echo -e "${YELLOW}Phase 1: Kubernetes Manifests & Kustomize Validation${NC}"

check "1. Observability k8s directory and manifests exist" \
    "[ -f '${OBS_DIR}/01-jaeger.yaml' ] && [ -f '${OBS_DIR}/02-otel-collector.yaml' ] && [ -f '${OBS_DIR}/kustomization.yaml' ]"

check "2. Kustomize validation completes without errors" \
    "kubectl kustomize '${OBS_DIR}' > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 2: OpenTelemetry Collector Configuration & Hardening${NC}"

check "3. OTel Collector ConfigMap defines OTLP receivers, Jaeger exporter, and pipelines" \
    "grep -q 'endpoint: 0.0.0.0:4317' '${OBS_DIR}/02-otel-collector.yaml' && \
     grep -q 'endpoint: 0.0.0.0:4318' '${OBS_DIR}/02-otel-collector.yaml' && \
     grep -q 'endpoint: jaeger:4317' '${OBS_DIR}/02-otel-collector.yaml' && \
     grep -q 'traces:' '${OBS_DIR}/02-otel-collector.yaml'"

check "4. OTel Collector deployment runs hardened (non-root UID 10001, drop ALL)" \
    "grep -q 'runAsNonRoot: true' '${OBS_DIR}/02-otel-collector.yaml' && \
     grep -q 'runAsUser: 10001' '${OBS_DIR}/02-otel-collector.yaml' && \
     grep -q 'drop:' '${OBS_DIR}/02-otel-collector.yaml' && \
     grep -q 'readOnlyRootFilesystem: true' '${OBS_DIR}/02-otel-collector.yaml'"

check "5. OTel Collector service exposes gRPC 4317, HTTP 4318, and metrics 8889" \
    "grep -q 'port: 4317' '${OBS_DIR}/02-otel-collector.yaml' && \
     grep -q 'port: 4318' '${OBS_DIR}/02-otel-collector.yaml' && \
     grep -q 'port: 8889' '${OBS_DIR}/02-otel-collector.yaml'"

echo -e "\n${YELLOW}Phase 3: Jaeger In-Cluster Distributed Tracing${NC}"

check "6. Jaeger deployment configured with OTLP ingestion and memory storage" \
    "grep -q 'COLLECTOR_OTLP_ENABLED' '${OBS_DIR}/01-jaeger.yaml' && \
     grep -q 'SPAN_STORAGE_TYPE' '${OBS_DIR}/01-jaeger.yaml' && \
     grep -q 'jaegertracing/all-in-one' '${OBS_DIR}/01-jaeger.yaml'"

check "7. Jaeger service exposes UI (16686) and OTLP receivers" \
    "grep -q 'port: 16686' '${OBS_DIR}/01-jaeger.yaml' && \
     grep -q 'port: 4317' '${OBS_DIR}/01-jaeger.yaml' && \
     grep -q 'name: jaeger-ui' '${OBS_DIR}/01-jaeger.yaml'"

echo -e "\n${YELLOW}Phase 4: Microservice Instrumentation & Network Policy Compliance${NC}"

check "8. Microservices route traces to in-cluster otel-collector service" \
    "grep -rq 'OTEL_EXPORTER_OTLP_ENDPOINT' '${DEPLOY_DIR}' && \
     grep -rq 'value: \"http://otel-collector:4317\"' '${DEPLOY_DIR}'"

check "9. Observability NetworkPolicy allows ingress on port 4317 from backend services" \
    "[ -f '${NP_FILE}' ] && \
     grep -q 'otel-collector' '${NP_FILE}' && \
     grep -q 'port: 4317' '${NP_FILE}'"

echo -e "\n${YELLOW}Phase 5: Trace Propagation & Documentation Verification${NC}"

check "10. Distributed tracing and OTel architecture documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: OpenTelemetry Collector and Jaeger Tracing' '${DOC_FILE}' && \
     grep -q 'W3C Trace Context' '${DOC_FILE}' && \
     grep -q 'Jaeger UI' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All OpenTelemetry Collector & Jaeger tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
