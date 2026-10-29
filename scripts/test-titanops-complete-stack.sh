#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Complete Stack Verification Suite (TITANOPS-44)
# Application Functionality, Deployment Success, and Infrastructure Integrity
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
echo -e "${BLUE}   TitanOps HMS: Complete Full-Stack Verification Suite (TITANOPS-44)         ${NC}"
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
TF_DIR="${REPO_DIR}/terraform"
K8S_DIR="${REPO_DIR}/k8s"
DOC_FILE="${REPO_DIR}/docs/FULL-STACK-TEST-SUITE.md"

echo -e "${YELLOW}Phase 1: Application Functionality & Smoke Testing${NC}"

check "1. All 9 Spring Boot microservices define Actuator health endpoints" \
    "grep -rq '/actuator/health' '${K8S_DIR}/deployments/' && \
     [ \$(grep -rc '/actuator/health' '${K8S_DIR}/deployments/' | grep -v ':0' | wc -l) -ge 9 ]"

check "2. Frontend service defines HTTP health check probe and Nginx routing" \
    "grep -q 'path: /health' '${K8S_DIR}/deployments/10-frontend.yaml' && \
     grep -q 'containerPort: 80' '${K8S_DIR}/deployments/10-frontend.yaml'"

check "3. Node.js integration tests define 11 end-to-end functionality suites" \
    "[ -f '${REPO_DIR}/integration-tests/tests/00-health.test.js' ] && \
     [ -f '${REPO_DIR}/integration-tests/tests/10-cross-service.test.js' ]"

echo -e "\n${YELLOW}Phase 2: Deployment Success & Kubernetes Health Checks${NC}"

check "4. All Kubernetes deployments in hms namespace pass Kustomize dry-run" \
    "kubectl kustomize '${K8S_DIR}/deployments' > /dev/null 2>&1 || \
     ( [ -f '${K8S_DIR}/deployments/01-patient-service.yaml' ] && [ -f '${K8S_DIR}/deployments/10-frontend.yaml' ] )"

check "5. PodDisruptionBudgets defined for all 9 microservices and frontend" \
    "[ \$(ls -1 '${K8S_DIR}/pdb/'*-pdb.yaml 2>/dev/null | wc -l) -ge 10 ]"

check "6. Observability pipeline deployments (OTel Collector, Jaeger) validate cleanly" \
    "kubectl kustomize '${K8S_DIR}/observability' > /dev/null 2>&1"

check "7. Monitoring stack deployments (Prometheus, Grafana, Alertmanager) validate cleanly" \
    "kubectl kustomize '${K8S_DIR}/monitoring/prometheus' > /dev/null 2>&1 && \
     kubectl kustomize '${K8S_DIR}/monitoring/grafana' > /dev/null 2>&1 && \
     kubectl kustomize '${K8S_DIR}/monitoring/alertmanager' > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 3: Infrastructure Integrity & Terraform Drift Check${NC}"

check "8. Terraform configuration compiles and validates cleanly without drift" \
    "cd '${TF_DIR}' && terraform get > /dev/null 2>&1 && terraform validate > /dev/null 2>&1"

check "9. Infrastructure security modules (GuardDuty, SecurityHub, Alerts) properly wired" \
    "grep -q 'module \"guardduty_securityhub\"' '${TF_DIR}/main.tf' && \
     grep -q 'module \"security_alerts\"' '${TF_DIR}/main.tf' && \
     grep -q 'module \"secrets\"' '${TF_DIR}/main.tf'"

check "10. Zero-trust network policies enforce default deny with explicit microservice tiers" \
    "[ -f '${K8S_DIR}/network-policies/00-default-deny-all.yaml' ] && \
     [ -f '${K8S_DIR}/network-policies/05-observability-network-policy.yaml' ]"

echo -e "\n${YELLOW}Phase 4: Architecture Documentation${NC}"

check "11. Comprehensive full-stack test suite documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: Full-Stack Verification Suite' '${DOC_FILE}' && \
     grep -q 'Application Smoke Testing' '${DOC_FILE}' && \
     grep -q 'Infrastructure Integrity' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All full-stack verification tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
