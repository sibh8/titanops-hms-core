#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Grafana EKS Installation & Dashboards Verification Suite
# Ticket: TITANOPS-40: Set up Grafana dashboards for app performance & resource health
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
echo -e "${BLUE}   TitanOps HMS: Grafana EKS Deployment Verification (TITANOPS-40)            ${NC}"
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
GRAFANA_DIR="${REPO_DIR}/k8s/monitoring/grafana"
DOC_FILE="${REPO_DIR}/docs/GRAFANA-EKS-SETUP.md"

echo -e "${YELLOW}Phase 1: Manifest Integrity & Kustomize Build${NC}"

check "1. Grafana manifests and dashboard files exist in k8s/monitoring/grafana" \
    "[ -f '${GRAFANA_DIR}/01-grafana-datasource-configmap.yaml' ] && \
     [ -f '${GRAFANA_DIR}/02-grafana-deployment.yaml' ] && \
     [ -f '${GRAFANA_DIR}/03-grafana-service.yaml' ] && \
     [ -f '${GRAFANA_DIR}/04-grafana-dashboards.yaml' ] && \
     [ -f '${GRAFANA_DIR}/kustomization.yaml' ]"

check "2. Kustomize builds monitoring/grafana bundle cleanly" \
    "kubectl kustomize '${GRAFANA_DIR}' > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 2: Prometheus Datasource Connection & Hardening${NC}"

check "3. Datasource ConfigMap connects to in-cluster Prometheus service" \
    "grep -q 'url: http://prometheus.monitoring.svc.cluster.local:9090' '${GRAFANA_DIR}/01-grafana-datasource-configmap.yaml' && \
     grep -q 'type: prometheus' '${GRAFANA_DIR}/01-grafana-datasource-configmap.yaml' && \
     grep -q 'isDefault: true' '${GRAFANA_DIR}/01-grafana-datasource-configmap.yaml'"

check "4. Grafana deployment enforces non-root UID 472 and dropped capabilities" \
    "grep -q 'runAsNonRoot: true' '${GRAFANA_DIR}/02-grafana-deployment.yaml' && \
     grep -q 'runAsUser: 472' '${GRAFANA_DIR}/02-grafana-deployment.yaml' && \
     grep -q 'drop:' '${GRAFANA_DIR}/02-grafana-deployment.yaml' && \
     grep -q '/api/health' '${GRAFANA_DIR}/02-grafana-deployment.yaml'"

check "5. Grafana Service exposes HTTP port 3000" \
    "grep -q 'port: 3000' '${GRAFANA_DIR}/03-grafana-service.yaml'"

echo -e "\n${YELLOW}Phase 3: Application Performance & Resource Health Dashboards${NC}"

check "6. Application Performance dashboard defines latency, error rate, and request metrics" \
    "grep -q 'TitanOps HMS - Application Performance' '${GRAFANA_DIR}/04-grafana-dashboards.yaml' && \
     grep -q 'http_server_requests_seconds_count' '${GRAFANA_DIR}/04-grafana-dashboards.yaml' && \
     grep -q 'histogram_quantile' '${GRAFANA_DIR}/04-grafana-dashboards.yaml'"

check "7. Node and Cluster Resource Health dashboard defines CPU, memory, and restart panels" \
    "grep -q 'TitanOps HMS - Node and Cluster Resource Health' '${GRAFANA_DIR}/04-grafana-dashboards.yaml' && \
     grep -q 'node_cpu_seconds_total' '${GRAFANA_DIR}/04-grafana-dashboards.yaml' && \
     grep -q 'node_memory_MemAvailable_bytes' '${GRAFANA_DIR}/04-grafana-dashboards.yaml' && \
     grep -q 'kube_pod_container_status_restarts_total' '${GRAFANA_DIR}/04-grafana-dashboards.yaml'"

echo -e "\n${YELLOW}Phase 4: Architecture Documentation${NC}"

check "8. Grafana setup and dashboard architecture documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: Grafana Dashboards for App Performance & Cluster Health' '${DOC_FILE}' && \
     grep -q 'Prometheus Datasource' '${DOC_FILE}' && \
     grep -q 'Port Forwarding' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All Grafana EKS deployment and dashboard tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
