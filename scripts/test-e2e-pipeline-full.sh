#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Full End-to-End CI/CD Pipeline Verification - TITANOPS-47
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

START_TIME=$(date +%s)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}   TITANOPS-47: Full CI/CD Pipeline End-to-End Integration Verification      ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}\n"

declare -a STAGE_NAMES=()
declare -a STAGE_RESULTS=()
declare -a STAGE_DURATIONS=()

run_stage() {
    local stage_name="$1"
    local command="$2"
    
    STAGE_NAMES+=("${stage_name}")
    echo -e "${YELLOW}${BOLD}▶ Executing Stage: ${stage_name}...${NC}"
    
    local t0=$(date +%s)
    if eval "${command}"; then
        local t1=$(date +%s)
        local delta=$((t1 - t0))
        STAGE_RESULTS+=("PASS")
        STAGE_DURATIONS+=("${delta}s")
        echo -e "  [${GREEN}PASS${NC}] ${stage_name} (Duration: ${delta}s)\n"
    else
        local t1=$(date +%s)
        local delta=$((t1 - t0))
        STAGE_RESULTS+=("FAIL")
        STAGE_DURATIONS+=("${delta}s")
        echo -e "  [${RED}FAIL${NC}] ${stage_name} (Duration: ${delta}s)\n"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Full Integrated Stages (Zero Manual Intervention)
# ------------------------------------------------------------------------------
run_stage "1. Secrets Scanning & Security Gate" \
    "\"${REPO_DIR}/scripts/test-secrets-scanning.sh\" > /dev/null 2>&1"

run_stage "2. Infrastructure Hardening & Cloud Policy Validation" \
    "\"${REPO_DIR}/terraform/test/verify-rds-irsa-lockdown.sh\" > /dev/null 2>&1"

run_stage "3. Configuration Management & Ansible Chaining" \
    "\"${REPO_DIR}/ansible/test/verify-ansible-terraform-chain.sh\" > /dev/null 2>&1"

run_stage "4. Zero-Trust Kubernetes Network Policies" \
    "\"${REPO_DIR}/k8s/network-policies/verify-network-policies.sh\" > /dev/null 2>&1"

run_stage "5. Multi-Environment Helm Parameterization & Values" \
    "\"${REPO_DIR}/helm/verify-environments.sh\" > /dev/null 2>&1"

run_stage "6. Helm SemVer Packaging & OCI Registry Retrieval" \
    "\"${REPO_DIR}/helm/verify-packaging.sh\" > /dev/null 2>&1"

run_stage "7. Helm Atomic Upgrade & Rollback Guardrails" \
    "\"${REPO_DIR}/helm/verify-helm-lifecycle.sh\" > /dev/null 2>&1"

run_stage "8. Container Health Checks & HPA Auto-Scaling" \
    "\"${REPO_DIR}/scripts/test-k8s-health-hpa.sh\" > /dev/null 2>&1"

run_stage "9. Dockerfile Hardening & Base Image Pinning" \
    "\"${REPO_DIR}/scripts/verify-dockerfile-hardening.sh\" > /dev/null 2>&1"

run_stage "10. Multi-Job CI/CD Orchestration Flow" \
    "\"${REPO_DIR}/scripts/verify-ci-cd-pipeline.sh\" > /dev/null 2>&1"

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo -e "${BLUE}${BOLD}==============================================================================${NC}"
echo -e "${BLUE}${BOLD}   Final Pipeline Execution Summary & Stage Timings Report                   ${NC}"
echo -e "${BLUE}${BOLD}==============================================================================${NC}"
printf "%-50s | %-10s | %-10s\n" "Pipeline Stage" "Status" "Duration"
echo "------------------------------------------------------------------------------"
ALL_PASSED=true
for i in "${!STAGE_NAMES[@]}"; do
    if [ "${STAGE_RESULTS[$i]}" = "PASS" ]; then
        STATUS_DISPLAY="${GREEN}PASSED${NC}"
    else
        STATUS_DISPLAY="${RED}FAILED${NC}"
        ALL_PASSED=false
    fi
    printf "%-50s | %-19b | %-10s\n" "${STAGE_NAMES[$i]}" "${STATUS_DISPLAY}" "${STAGE_DURATIONS[$i]}"
done
echo "------------------------------------------------------------------------------"
echo -e "Total Pipeline Integration Runtime: ${BOLD}${TOTAL_DURATION} seconds${NC}\n"

if [ "$ALL_PASSED" = true ]; then
    echo -e "${GREEN}${BOLD}✓ FULL PIPELINE RUN COMPLETED END-TO-END WITH ZERO MANUAL INTERVENTION!${NC}"
    echo -e "${GREEN}All Definition of Done criteria for TITANOPS-47 are satisfied.${NC}\n"
    exit 0
else
    echo -e "${RED}${BOLD}✗ One or more pipeline stages failed.${NC}\n"
    exit 1
fi
