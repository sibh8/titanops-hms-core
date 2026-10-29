#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Multi-Service ECR Build & Push Verification Suite
# Ticket: TITANOPS-65 (and subtasks TITANOPS-76 through TITANOPS-85)
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
echo -e "${BLUE}   TitanOps HMS: Docker Build & ECR Push Verification (TITANOPS-65)           ${NC}"
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

echo -e "${YELLOW}Phase 1: Dockerfile Presence & Hardening Audit (All 10 Services)${NC}"
SERVICES=(
    "patient-service:8081:10001"
    "appointment-service:8082:10001"
    "user-service:8083:10001"
    "billing-service:8084:10001"
    "encounter-service:8085:10001"
    "lab-service:8086:10001"
    "medication-service:8087:10001"
    "prescription-service:8088:10001"
    "provider-service:8089:10001"
    "frontend:80:101"
)

for entry in "${SERVICES[@]}"; do
    IFS=":" read -r svc_dir port uid <<< "${entry}"
    check "Dockerfile exists for ${svc_dir}" \
        "[ -f '${REPO_DIR}/${svc_dir}/Dockerfile' ]"
    check "Non-root USER configured in ${svc_dir}/Dockerfile" \
        "grep -q 'USER ${uid}' '${REPO_DIR}/${svc_dir}/Dockerfile'"
done

echo -e "\n${YELLOW}Phase 2: Frontend Health Check Configuration${NC}"
check "Frontend Dockerfile includes HEALTHCHECK endpoint" \
    "grep -q 'HEALTHCHECK' '${REPO_DIR}/frontend/Dockerfile' && grep -q '/health' '${REPO_DIR}/frontend/Dockerfile'"

echo -e "\n${YELLOW}Phase 3: ECR Build & Push Automation Script${NC}"
check "build-and-push-ecr.sh script is executable" \
    "[ -x '${REPO_DIR}/scripts/build-and-push-ecr.sh' ]"

check "build-and-push-ecr.sh dry-run executes cleanly" \
    "'${REPO_DIR}/scripts/build-and-push-ecr.sh' --dry-run > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 4: GitHub Actions Workflow Validation${NC}"
check "build-and-push-all-ecr.yml workflow exists and parses as valid YAML" \
    "[ -f '${REPO_DIR}/.github/workflows/build-and-push-all-ecr.yml' ] && ruby -ryaml -e \"YAML.load_file('${REPO_DIR}/.github/workflows/build-and-push-all-ecr.yml')\" > /dev/null 2>&1"


echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-65 Multi-Service ECR Build & Push verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
