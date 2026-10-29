#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Pod SecurityContext Hardening Verification Suite
# Ticket: TITANOPS-131: Harden pod securityContext (non-root, read-only root, dropped capabilities)
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
echo -e "${BLUE}   TitanOps HMS: Pod Security Hardening Verification (TITANOPS-131)           ${NC}"
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
DEPLOY_DIR="${REPO_DIR}/k8s/deployments"

SERVICES=(
    "01-patient-service.yaml:patient-service:10001"
    "02-appointment-service.yaml:appointment-service:10001"
    "03-user-service.yaml:user-service:10001"
    "04-billing-service.yaml:billing-service:10001"
    "05-encounter-service.yaml:encounter-service:10001"
    "06-lab-service.yaml:lab-service:10001"
    "07-medication-service.yaml:medication-service:10001"
    "08-prescription-service.yaml:prescription-service:10001"
    "09-provider-service.yaml:provider-service:10001"
    "10-frontend.yaml:frontend:101"
)

echo -e "${YELLOW}Phase 1: Pod Security Standards (PSS) Restricted Compliance Audit${NC}"
for entry in "${SERVICES[@]}"; do
    IFS=":" read -r file name uid <<< "${entry}"
    check "Pod enforces runAsNonRoot: true in ${file}" \
        "grep -q 'runAsNonRoot: true' '${DEPLOY_DIR}/${file}'"
    check "Pod enforces explicit non-root UID (${uid}) in ${file}" \
        "grep -q 'runAsUser: ${uid}' '${DEPLOY_DIR}/${file}'"
    check "Container enforces readOnlyRootFilesystem: true in ${file}" \
        "grep -q 'readOnlyRootFilesystem: true' '${DEPLOY_DIR}/${file}'"
    check "Container enforces allowPrivilegeEscalation: false in ${file}" \
        "grep -q 'allowPrivilegeEscalation: false' '${DEPLOY_DIR}/${file}'"
    check "Container drops ALL Linux capabilities in ${file}" \
        "grep -A 3 'capabilities:' '${DEPLOY_DIR}/${file}' | grep -q 'ALL'"
    check "Ephemeral emptyDir volume mounted for /tmp in ${file}" \
        "grep -A 3 'volumeMounts:' '${DEPLOY_DIR}/${file}' | grep -q 'mountPath: /tmp'"
done

echo -e "\n${YELLOW}Phase 2: Helm Chart Security Baseline Audit${NC}"
check "Helm values.yaml enforces runAsNonRoot: true" \
    "grep -q 'runAsNonRoot: true' '${REPO_DIR}/helm/titanops-base/values.yaml'"

check "Helm values.yaml enforces readOnlyRootFilesystem: true" \
    "grep -q 'readOnlyRootFilesystem: true' '${REPO_DIR}/helm/titanops-base/values.yaml'"

check "Helm values.yaml drops ALL capabilities" \
    "grep -A 3 'capabilities:' '${REPO_DIR}/helm/titanops-base/values.yaml' | grep -q 'ALL'"

check "Helm rendered multi-workload template enforces read-only root filesystems" \
    "helm template titanops-audit '${REPO_DIR}/helm/titanops-base' | grep -q 'readOnlyRootFilesystem: true'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-131 Pod Security Hardening verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
