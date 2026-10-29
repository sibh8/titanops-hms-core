#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Grafana Dashboards Provisioning Verification Suite
# Ticket: TITANOPS-75: Import existing Grafana dashboards into EKS via ConfigMaps
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
echo -e "${BLUE}   TitanOps HMS: Grafana Dashboards Provisioning Verification (TITANOPS-75)   ${NC}"
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
GRAFANA_REPO="${REPO_DIR}/grafana"
GRAFANA_K8S="${REPO_DIR}/k8s/monitoring/grafana"
DOC_FILE="${REPO_DIR}/docs/GRAFANA-DASHBOARDS-PROVISIONING.md"

echo -e "${YELLOW}Phase 1: Existing Repository Dashboard Assets Integrity${NC}"

check "1. All 4 original repository dashboards exist and are non-empty" \
    "[ -s '${GRAFANA_REPO}/dashboards/business-metrics.json' ] && \
     [ -s '${GRAFANA_REPO}/dashboards/functional.json' ] && \
     [ -s '${GRAFANA_REPO}/dashboards/medicore-hms.json' ] && \
     [ -s '${GRAFANA_REPO}/dashboards/operational.json' ]"

echo -e "\n${YELLOW}Phase 2: Kubernetes ConfigMap Dashboard Ingestion${NC}"

check "2. ConfigMap 05-imported-dashboards-configmap.yaml packages all 4 dashboards" \
    "grep -q 'name: grafana-dashboards-imported' '${GRAFANA_K8S}/05-imported-dashboards-configmap.yaml' && \
     grep -q 'business-metrics.json:' '${GRAFANA_K8S}/05-imported-dashboards-configmap.yaml' && \
     grep -q 'functional.json:' '${GRAFANA_K8S}/05-imported-dashboards-configmap.yaml' && \
     grep -q 'medicore-hms.json:' '${GRAFANA_K8S}/05-imported-dashboards-configmap.yaml' && \
     grep -q 'operational.json:' '${GRAFANA_K8S}/05-imported-dashboards-configmap.yaml'"

check "3. Grafana deployment mounts imported dashboards at /etc/grafana/dashboards" \
    "grep -q 'mountPath: /etc/grafana/dashboards' '${GRAFANA_K8S}/02-grafana-deployment.yaml' && \
     grep -q 'name: grafana-dashboards-imported' '${GRAFANA_K8S}/02-grafana-deployment.yaml'"

check "4. Dashboard provider configuration registers /etc/grafana/dashboards" \
    "grep -q 'path: /etc/grafana/dashboards' '${GRAFANA_K8S}/04-grafana-dashboards.yaml' && \
     grep -q 'updateIntervalSeconds:' '${GRAFANA_K8S}/04-grafana-dashboards.yaml'"

echo -e "\n${YELLOW}Phase 3: In-Cluster Prometheus Datasource Verification${NC}"

check "5. In-cluster datasource points to internal Prometheus service FQDN" \
    "grep -q 'url: http://prometheus.monitoring.svc.cluster.local:9090' '${GRAFANA_K8S}/01-grafana-datasource-configmap.yaml' && \
     grep -q 'url: http://prometheus.monitoring.svc.cluster.local:9090' '${GRAFANA_REPO}/provisioning/datasources/datasource.yml'"

check "6. Kustomize builds Grafana monitoring suite cleanly" \
    "kubectl kustomize '${GRAFANA_K8S}' > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 4: Architecture Documentation${NC}"

check "7. Documentation exists detailing imported dashboards and provisioning" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: Imported Grafana Dashboards' '${DOC_FILE}' && \
     grep -q 'business-metrics.json' '${DOC_FILE}' && \
     grep -q 'medicore-hms.json' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All Grafana dashboard importing tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
