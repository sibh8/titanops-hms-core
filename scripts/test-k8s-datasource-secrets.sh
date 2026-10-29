#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Kubernetes DataSource Secret Verification Suite
# Ticket: TITANOPS-71: Create K8s Secrets for Spring datasource credentials
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
echo -e "${BLUE}   TitanOps HMS: K8s DataSource Secret Verification (TITANOPS-71)              ${NC}"
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

echo -e "${YELLOW}Phase 1: No Plaintext Passwords in Helm Values${NC}"
check "1. Zero plaintext SPRING_DATASOURCE_PASSWORD occurrences in helm values" \
    "! grep -rn 'SPRING_DATASOURCE_PASSWORD.*:.*\"' '${REPO_DIR}/helm/values/'"

SERVICES=(
    "patient-service"
    "appointment-service"
    "user-service"
    "billing-service"
    "encounter-service"
    "lab-service"
    "medication-service"
    "prescription-service"
    "provider-service"
)

echo -e "\n${YELLOW}Phase 2: Service Values Reference titanops-datasource-credentials${NC}"
for svc in "${SERVICES[@]}"; do
    check "2. ${svc}.yaml references secretRef 'titanops-datasource-credentials'" \
        "grep -q 'name: titanops-datasource-credentials' '${REPO_DIR}/helm/values/${svc}.yaml'"
done

echo -e "\n${YELLOW}Phase 3: Secret Template & Generator Script${NC}"
check "3. Secret template manifest exists in k8s/secrets/" \
    "[ -f '${REPO_DIR}/k8s/secrets/datasource-secret-template.yaml' ]"

check "4. Secret generator script is executable" \
    "[ -x '${REPO_DIR}/scripts/generate-datasource-secret.sh' ]"

check "5. Secret generator produces valid Kubernetes Secret manifest" \
    "DB_PASSWORD='test_secret_pass' '${REPO_DIR}/scripts/generate-datasource-secret.sh' | grep -q 'name: titanops-datasource-credentials'"

echo -e "\n${YELLOW}Phase 4: Helm Template Rendering Validation${NC}"
for svc in "${SERVICES[@]}"; do
    check "6. Helm template renders cleanly with secret for ${svc}" \
        "helm template 'test-${svc}' '${REPO_DIR}/helm/titanops-base' -f '${REPO_DIR}/helm/values/${svc}.yaml' | grep -A 3 'envFrom:' | grep -q 'titanops-datasource-credentials'"
done

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-71 K8s DataSource Secret verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
