#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: ECR Repositories Automated Verification Suite
# Ticket: TITANOPS-68: Create ECR repositories via Terraform for all 10 service images
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
echo -e "${BLUE}   TitanOps HMS: ECR Repositories Terraform Verification (TITANOPS-68)        ${NC}"
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

echo -e "${YELLOW}Phase 1: Terraform Syntax & Module Validation${NC}"
check "1. Terraform formatting adheres to canonical style" \
    "cd '${TF_DIR}' && terraform fmt -check -recursive > /dev/null 2>&1"

check "2. Terraform configuration with ECR module validates cleanly" \
    "cd '${TF_DIR}' && terraform validate > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 2: ECR Repository Definitions (All 10 Services)${NC}"
SERVICES=(
    "medicore/patient-service"
    "medicore/appointment-service"
    "medicore/user-service"
    "medicore/billing-service"
    "medicore/encounter-service"
    "medicore/lab-service"
    "medicore/medication-service"
    "medicore/prescription-service"
    "medicore/provider-service"
    "medicore/frontend"
)

for svc in "${SERVICES[@]}"; do
    check "3. ECR repository defined: ${svc}" \
        "grep -q '\"${svc}\"' '${TF_DIR}/modules/ecr/variables.tf'"
done

echo -e "\n${YELLOW}Phase 3: Image Scanning & Lifecycle Policies${NC}"
check "4. Image scanning on push is enabled" \
    "grep -q 'scan_on_push' '${TF_DIR}/modules/ecr/variables.tf' && grep -q 'scan_on_push *= *var.scan_on_push' '${TF_DIR}/modules/ecr/main.tf'"

check "5. Server-side encryption is configured" \
    "grep -q 'encryption_configuration' '${TF_DIR}/modules/ecr/main.tf'"

check "6. Lifecycle policy expires untagged images" \
    "grep -q 'tagStatus.*=.*\"untagged\"' '${TF_DIR}/modules/ecr/main.tf'"

check "7. Lifecycle policy caps retained tagged images (max 30)" \
    "grep -q 'max_image_count' '${TF_DIR}/modules/ecr/variables.tf' && grep -q 'imageCountMoreThan' '${TF_DIR}/modules/ecr/main.tf'"

echo -e "\n${YELLOW}Phase 4: Module Wiring & Outputs${NC}"
check "8. ECR module is wired into root main.tf" \
    "grep -q 'module \"ecr\"' '${TF_DIR}/main.tf'"

check "9. Root outputs export ecr_repository_urls" \
    "grep -q 'output \"ecr_repository_urls\"' '${TF_DIR}/outputs.tf'"

check "10. Root outputs export ecr_repository_arns" \
    "grep -q 'output \"ecr_repository_arns\"' '${TF_DIR}/outputs.tf'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-68 ECR repositories verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
