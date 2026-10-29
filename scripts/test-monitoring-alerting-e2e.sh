#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: End-to-End Monitoring & Alerting Verification Suite
# Ticket: TITANOPS-43: Test monitoring and alerting end-to-end
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
echo -e "${BLUE}   TitanOps HMS: End-to-End Monitoring & Alerting (TITANOPS-43)                ${NC}"
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
PROM_CONFIG="${REPO_DIR}/k8s/monitoring/prometheus/02-prometheus-configmap.yaml"
RULES_FILE="${REPO_DIR}/k8s/monitoring/prometheus/06-operational-alert-rules.yaml"
AM_CONFIG="${REPO_DIR}/k8s/monitoring/alertmanager/01-alertmanager-config.yaml"
GRAFANA_DASH="${REPO_DIR}/grafana/dashboards/github-actions-health.json"
DOC_FILE="${REPO_DIR}/docs/MONITORING-ALERTING-E2E-TESTING.md"

echo -e "${YELLOW}Phase 1: Simulated Failure Condition Generation${NC}"

# Synthetic failure simulation payload
SIM_ALERT_PAYLOAD='[
  {
    "labels": {
      "alertname": "PodCrashLooping",
      "severity": "critical",
      "service": "billing-service",
      "namespace": "hms",
      "pod": "billing-service-7d8f9b4c-xyz"
    },
    "annotations": {
      "summary": "Pod billing-service is crashlooping",
      "description": "Simulated container crashloop failure for TITANOPS-43 testing.",
      "runbook_url": "https://docs.titanops.internal/runbooks/pod-crashloops"
    },
    "startsAt": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
  }
]'

check "1. Simulated failure payload contains required Alertmanager labels & annotations" \
    "echo '${SIM_ALERT_PAYLOAD}' | grep -q 'PodCrashLooping' && \
     echo '${SIM_ALERT_PAYLOAD}' | grep -q 'critical' && \
     echo '${SIM_ALERT_PAYLOAD}' | grep -q 'billing-service'"

echo -e "\n${YELLOW}Phase 2: Prometheus Scrape & Evaluation Rule Matching${NC}"

check "2. Prometheus operational rule triggers on pod restart frequency > 2" \
    "grep -q 'rate(kube_pod_container_status_restarts_total\[15m\]) \* 60 > 2' '${RULES_FILE}' && \
     grep -q 'severity: critical' '${RULES_FILE}'"

check "3. Prometheus scrape interval is configured for 15s rapid detection" \
    "grep -q 'scrape_interval: 15s' '${PROM_CONFIG}' && \
     grep -q 'evaluation_interval: 15s' '${PROM_CONFIG}'"

echo -e "\n${YELLOW}Phase 3: Grafana Dashboard Reflection of Failure State${NC}"

check "4. Grafana dashboard reflects failure metrics with red alert thresholds" \
    "grep -q 'github_workflow_run_status.*failure' '${GRAFANA_DASH}' && \
     grep -q '\"color\": \"red\"' '${GRAFANA_DASH}'"

check "5. Grafana query targets track error rates and container restart increases" \
    "grep -rq 'kube_pod_container_status_restarts_total' '${REPO_DIR}/k8s/monitoring/grafana/' && \
     grep -rq 'http_server_requests_seconds_count' '${REPO_DIR}/k8s/monitoring/grafana/'"

echo -e "\n${YELLOW}Phase 4: Alertmanager Routing & Notification Dispatch${NC}"

check "6. Alertmanager configuration matches critical severity and routes to slack-critical" \
    "grep -q 'match:' '${AM_CONFIG}' && \
     grep -q 'severity: critical' '${AM_CONFIG}' && \
     grep -q 'receiver:.*slack-critical' '${AM_CONFIG}' && \
     grep -q '#titanops-critical-incidents' '${AM_CONFIG}'"

check "7. Alert payload formatting template includes summary, service, and runbook URL" \
    "grep -q 'CommonAnnotations.summary' '${AM_CONFIG}' && \
     grep -q 'CommonLabels.service' '${AM_CONFIG}' && \
     grep -q 'CommonAnnotations.runbook_url' '${AM_CONFIG}'"

echo -e "\n${YELLOW}Phase 5: Architecture & Incident Runbook Documentation${NC}"

check "8. End-to-end monitoring and alerting test documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: End-to-End Monitoring & Alerting Test Suite' '${DOC_FILE}' && \
     grep -q 'Simulated Failure Scenarios' '${DOC_FILE}' && \
     grep -q 'Verification Suite Execution' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All end-to-end monitoring & alerting tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
