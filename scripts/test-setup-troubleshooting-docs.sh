#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Master Setup & Troubleshooting Documentation Verification Suite
# Ticket: TITANOPS-45: Document GitHub Actions, Terraform, Ansible & Helm
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
echo -e "${BLUE}   TitanOps HMS: Setup & Troubleshooting Docs Verification (TITANOPS-45)      ${NC}"
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
DOC_FILE="${REPO_DIR}/docs/SETUP-AND-TROUBLESHOOTING-GUIDE.md"

echo -e "${YELLOW}Phase 1: Document Structure & Completeness${NC}"

check "1. Master setup & troubleshooting guide exists and is non-empty" \
    "[ -s '${DOC_FILE}' ]"

check "2. Document details system prerequisites and environment tooling" \
    "grep -q 'Tooling Requirements' '${DOC_FILE}' && \
     grep -q 'Terraform' '${DOC_FILE}' && \
     grep -q 'kubectl' '${DOC_FILE}' && \
     grep -q 'Helm' '${DOC_FILE}'"

echo -e "\n${YELLOW}Phase 2: Setup & Usage for Core Stacks${NC}"

check "3. Details setup and usage for GitHub Actions CI/CD" \
    "grep -q 'GitHub Actions CI/CD Setup & Troubleshooting' '${DOC_FILE}' && \
     grep -q 'OIDC' '${DOC_FILE}'"

check "4. Details setup and usage for Terraform infrastructure" \
    "grep -q 'Terraform Infrastructure Setup & Troubleshooting' '${DOC_FILE}' && \
     grep -q 'terraform apply' '${DOC_FILE}'"

check "5. Details setup and usage for Ansible configuration management" \
    "grep -q 'Ansible Configuration Management Setup & Troubleshooting' '${DOC_FILE}' && \
     grep -q 'ansible-playbook' '${DOC_FILE}'"

check "6. Details setup and usage for Helm & Kubernetes deployments" \
    "grep -q 'Helm & Kubernetes Deployment Setup & Troubleshooting' '${DOC_FILE}' && \
     grep -q 'helm upgrade --install' '${DOC_FILE}'"

echo -e "\n${YELLOW}Phase 3: Real-World Troubleshooting Scenarios${NC}"

check "7. Includes real troubleshooting cases for GitHub Actions (OIDC, disk space, signing)" \
    "grep -q 'AssumeRoleWithWebIdentity' '${DOC_FILE}' && \
     grep -q 'No space left on device' '${DOC_FILE}' && \
     grep -q 'Cosign container image signature' '${DOC_FILE}'"

check "8. Includes real troubleshooting cases for Terraform (modules, RDS AZs, DynamoDB lock)" \
    "grep -q 'Module not installed' '${DOC_FILE}' && \
     grep -q 'DBSubnetGroupDoesNotCoverEnoughAZs' '${DOC_FILE}' && \
     grep -q 'DynamoDB lock' '${DOC_FILE}'"

check "9. Includes real troubleshooting cases for Ansible (host key, dynamic inventory, python)" \
    "grep -q 'Host key verification failed' '${DOC_FILE}' && \
     grep -q 'Dynamic inventory aws_ec2' '${DOC_FILE}' && \
     grep -q 'Python interpreter discovery failed' '${DOC_FILE}'"

check "10. Includes real troubleshooting cases for Helm & Monitoring" \
    "grep -q 'timed out waiting for the condition' '${DOC_FILE}' && \
     grep -q 'CustomResourceDefinition external-secrets' '${DOC_FILE}' && \
     grep -q 'Prometheus target shows DOWN' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All setup & troubleshooting documentation tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
