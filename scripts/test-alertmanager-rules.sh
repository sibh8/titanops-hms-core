#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Alertmanager & Operational Alert Rules Verification Suite
# Ticket: TITANOPS-42: Configure Prometheus alerting rules and failure alerts
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
echo -e "${BLUE}   TitanOps HMS: Alertmanager & Operational Alerts (TITANOPS-42)              ${NC}"
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
AM_DIR="${REPO_DIR}/k8s/monitoring/alertmanager"
RULES_FILE="${REPO_DIR}/k8s/monitoring/prometheus/06-operational-alert-rules.yaml"
PROM_CONFIG="${REPO_DIR}/k8s/monitoring/prometheus/02-prometheus-configmap.yaml"
WORKFLOW_FILE="${REPO_DIR}/.github/workflows/ci-health-metrics.yml"
DOC_FILE="${REPO_DIR}/docs/ALERTMANAGER-AND-NOTIFICATIONS.md"

echo -e "${YELLOW}Phase 1: Alertmanager Manifest & Kustomize Validation${NC}"

check "1. Alertmanager manifests and kustomization exist" \
    "[ -f '${AM_DIR}/01-alertmanager-config.yaml' ] && \
     [ -f '${AM_DIR}/02-alertmanager-deployment.yaml' ] && \
     [ -f '${AM_DIR}/kustomization.yaml' ]"

check "2. Kustomize builds alertmanager bundle cleanly" \
    "kubectl kustomize '${AM_DIR}' > /dev/null 2>&1"

check "3. Alertmanager config defines notification routes for Slack and security webhook" \
    "grep -q '#titanops-alerts' '${AM_DIR}/01-alertmanager-config.yaml' && \
     grep -q '#titanops-critical-incidents' '${AM_DIR}/01-alertmanager-config.yaml' && \
     grep -q 'security-webhook' '${AM_DIR}/01-alertmanager-config.yaml'"

echo -e "\n${YELLOW}Phase 2: Prometheus Operational Alerting Rules${NC}"

check "4. PrometheusRule defines PodCrashLooping, High 5xx, Node Pressure, and Rollout Failure" \
    "[ -f '${RULES_FILE}' ] && \
     grep -q 'alert: PodCrashLooping' '${RULES_FILE}' && \
     grep -q 'alert: MicroserviceHigh5xxErrorRate' '${RULES_FILE}' && \
     grep -q 'alert: KubernetesNodeMemoryPressure' '${RULES_FILE}' && \
     grep -q 'alert: FailedDeploymentRollout' '${RULES_FILE}'"

check "5. Prometheus ConfigMap wires Alertmanager endpoint on port 9093" \
    "grep -q 'alertmanager.monitoring.svc.cluster.local:9093' '${PROM_CONFIG}'"

echo -e "\n${YELLOW}Phase 3: GitHub Actions Failure Notifications${NC}"

check "6. GitHub Actions workflow includes failure notification step with if: failure()" \
    "[ -f '${WORKFLOW_FILE}' ] && \
     grep -q 'if: failure()' '${WORKFLOW_FILE}' && \
     grep -q 'Dispatch Slack & Email Notification on CI/CD Failure' '${WORKFLOW_FILE}'"

echo -e "\n${YELLOW}Phase 4: Architecture Documentation${NC}"

check "7. Alertmanager routing and notification documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: Alertmanager & Operational Alerting Rules' '${DOC_FILE}' && \
     grep -q 'PodCrashLooping' '${DOC_FILE}' && \
     grep -q 'Notification Channels' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All Alertmanager & alerting rule tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
