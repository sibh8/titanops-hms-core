#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: GitHub Actions Monitoring Verification Suite
# Ticket: TITANOPS-41: Integrate GitHub Actions workflow health into Prometheus/Grafana
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
echo -e "${BLUE}   TitanOps HMS: GitHub Actions Monitoring Verification (TITANOPS-41)         ${NC}"
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
EXPORTER_DIR="${REPO_DIR}/k8s/monitoring/ci-cd-exporter"
PROM_CONFIG="${REPO_DIR}/k8s/monitoring/prometheus/02-prometheus-configmap.yaml"
HELM_VALUES="${REPO_DIR}/k8s/monitoring/prometheus/helm-values.yaml"
GRAFANA_DASH="${REPO_DIR}/grafana/dashboards/github-actions-health.json"
GRAFANA_CM="${REPO_DIR}/k8s/monitoring/grafana/05-imported-dashboards-configmap.yaml"
WORKFLOW_FILE="${REPO_DIR}/.github/workflows/ci-health-metrics.yml"
DOC_FILE="${REPO_DIR}/docs/GITHUB-ACTIONS-PROMETHEUS-GRAFANA.md"

echo -e "${YELLOW}Phase 1: Metrics Exporter & Pushgateway Manifest Verification${NC}"

check "1. GitHub Actions exporter and Pushgateway manifests exist" \
    "[ -f '${EXPORTER_DIR}/01-github-actions-exporter.yaml' ] && \
     [ -f '${EXPORTER_DIR}/02-pushgateway.yaml' ] && \
     [ -f '${EXPORTER_DIR}/kustomization.yaml' ]"

check "2. Kustomize builds ci-cd-exporter manifests cleanly" \
    "kubectl kustomize '${EXPORTER_DIR}' > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 2: Prometheus Scrape Configuration for CI/CD Metrics${NC}"

check "3. Prometheus ConfigMap configures github-actions-exporter and pushgateway jobs" \
    "grep -q 'job_name:.*github-actions-exporter' '${PROM_CONFIG}' && \
     grep -q 'github-actions-exporter.monitoring.svc.cluster.local:9999' '${PROM_CONFIG}' && \
     grep -q 'job_name:.*pushgateway' '${PROM_CONFIG}' && \
     grep -q 'pushgateway.monitoring.svc.cluster.local:9091' '${PROM_CONFIG}'"

check "4. Helm values file configures CI/CD scrape endpoints in additionalScrapeConfigs" \
    "grep -q 'job_name:.*github-actions-exporter' '${HELM_VALUES}' && \
     grep -q 'job_name:.*pushgateway' '${HELM_VALUES}'"

echo -e "\n${YELLOW}Phase 3: Grafana Dashboard & Failure Visibility${NC}"

check "5. Grafana dashboard defines Success Rate gauge, run trends, and failed runs table" \
    "[ -f '${GRAFANA_DASH}' ] && \
     grep -q 'github_workflow_run_status' '${GRAFANA_DASH}' && \
     grep -q 'Workflow Success Rate' '${GRAFANA_DASH}' && \
     grep -q 'Recent Failed Workflow Runs' '${GRAFANA_DASH}' && \
     grep -q 'conclusion.*failure' '${GRAFANA_DASH}'"

check "6. Grafana ConfigMap 05-imported-dashboards-configmap.yaml includes CI/CD dashboard" \
    "grep -q 'github-actions-health.json:' '${GRAFANA_CM}'"

echo -e "\n${YELLOW}Phase 4: GitHub Actions Workflow Integration & Documentation${NC}"

check "7. GitHub Actions telemetry workflow exports Prometheus metrics format" \
    "[ -f '${WORKFLOW_FILE}' ] && \
     grep -q 'github_workflow_run_status' '${WORKFLOW_FILE}' && \
     grep -q 'github_workflow_run_total' '${WORKFLOW_FILE}'"

check "8. Architecture and operational documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: GitHub Actions Telemetry in Prometheus and Grafana' '${DOC_FILE}' && \
     grep -q 'Pushgateway' '${DOC_FILE}' && \
     grep -q 'Failure Visibility' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All GitHub Actions monitoring integration tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
