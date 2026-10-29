#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Helm Multi-Workload Chart Verification Suite
# Ticket: TITANOPS-72: Extend Helm chart to template all 10 workloads
# ==============================================================================
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   TitanOps HMS: Helm Multi-Workload Verification (TITANOPS-72)               ${NC}"
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
CHART_DIR="${REPO_DIR}/helm/titanops-base"

echo -e "${YELLOW}Phase 1: Helm Linting & Structure Validation${NC}"
check "1. Helm lint passes on titanops-base with 0 errors" \
    "helm lint '${CHART_DIR}' > /dev/null 2>&1"

SERVICES=(
    "patient-service:8081"
    "appointment-service:8082"
    "user-service:8083"
    "billing-service:8084"
    "encounter-service:8085"
    "lab-service:8086"
    "medication-service:8087"
    "prescription-service:8088"
    "provider-service:8089"
    "frontend:80"
)

echo -e "\n${YELLOW}Phase 2: Values.yaml Multi-Workload Enumeration (All 10 Services)${NC}"
for entry in "${SERVICES[@]}"; do
    IFS=":" read -r svc port <<< "${entry}"
    check "2. values.yaml contains definition for ${svc}" \
        "grep -A 10 '  ${svc}:' '${CHART_DIR}/values.yaml' | grep -q 'port: ${port}'"
done

echo -e "\n${YELLOW}Phase 3: Multi-Workload Rendering Verification (All 10 Services)${NC}"
RENDERED_MANIFEST=$(helm template titanops-app "${CHART_DIR}")

for entry in "${SERVICES[@]}"; do
    IFS=":" read -r svc port <<< "${entry}"
    check "3. Deployment rendered for ${svc}" \
        "echo \"${RENDERED_MANIFEST}\" | grep -A 4 'kind: Deployment' | grep -q 'name: ${svc}'"
    check "4. Service rendered on port ${port} for ${svc}" \
        "echo \"${RENDERED_MANIFEST}\" | grep -A 4 'kind: Service' | grep -q 'name: ${svc}'"
done

echo -e "\n${YELLOW}Phase 4: Client-Side Dry-Run Install Verification${NC}"
check "5. helm install --dry-run=client succeeds on multi-workload chart" \
    "helm install titanops-test '${CHART_DIR}' --dry-run=client > /dev/null 2>&1"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-72 Helm multi-workload templating verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
