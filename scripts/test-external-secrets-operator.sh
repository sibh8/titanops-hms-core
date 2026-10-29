#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: External Secrets Operator (ESO) Verification Suite
# Ticket: TITANOPS-127: Integrate AWS Secrets Manager via External Secrets Operator
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
echo -e "${BLUE}   TitanOps HMS: External Secrets Operator Verification (TITANOPS-127)        ${NC}"
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
ESO_DIR="${REPO_DIR}/k8s/external-secrets"

echo -e "${YELLOW}Phase 1: Terraform Secrets Manager Infrastructure${NC}"
check "1. Terraform configuration with secrets module validates cleanly" \
    "cd '${TF_DIR}' && terraform validate > /dev/null 2>&1"

check "2. AWS Secrets Manager secret declared for database credentials" \
    "grep -q 'resource \"aws_secretsmanager_secret\" \"database\"' '${TF_DIR}/modules/secrets/main.tf'"

check "3. AWS Secrets Manager secret declared for Grafana credentials" \
    "grep -q 'resource \"aws_secretsmanager_secret\" \"grafana\"' '${TF_DIR}/modules/secrets/main.tf'"

check "4. IAM IRSA role and policy configured for External Secrets Operator" \
    "grep -q 'resource \"aws_iam_role\" \"external_secrets\"' '${TF_DIR}/modules/secrets/main.tf' && grep -q 'secretsmanager:GetSecretValue' '${TF_DIR}/modules/secrets/main.tf'"

echo -e "\n${YELLOW}Phase 2: Kubernetes External Secrets Operator Manifests${NC}"
check "5. SecretStore manifest exists and parses as valid YAML" \
    "[ -f '${ESO_DIR}/01-eso-serviceaccount-secretstore.yaml' ] && ruby -ryaml -e \"YAML.load_stream(File.read('${ESO_DIR}/01-eso-serviceaccount-secretstore.yaml'))\" > /dev/null 2>&1"

check "6. SecretStore uses IRSA JWT authentication with external-secrets-sa" \
    "grep -A 5 'auth:' '${ESO_DIR}/01-eso-serviceaccount-secretstore.yaml' | grep -q 'external-secrets-sa'"

check "7. Database ExternalSecret syncs to target titanops-datasource-credentials" \
    "grep -A 3 'target:' '${ESO_DIR}/02-database-external-secret.yaml' | grep -q 'name: titanops-datasource-credentials'"

check "8. Database ExternalSecret extracts SPRING_DATASOURCE_* properties" \
    "grep -q 'SPRING_DATASOURCE_URL' '${ESO_DIR}/02-database-external-secret.yaml' && grep -q 'SPRING_DATASOURCE_PASSWORD' '${ESO_DIR}/02-database-external-secret.yaml'"

check "9. Grafana ExternalSecret syncs to target grafana-admin-credentials" \
    "grep -A 3 'target:' '${ESO_DIR}/03-grafana-external-secret.yaml' | grep -q 'name: grafana-admin-credentials'"

echo -e "\n${YELLOW}Phase 3: Plaintext Credential Elimination Audit${NC}"
check "10. Zero plaintext database password defaults in Helm values" \
    "! grep -rn 'SPRING_DATASOURCE_PASSWORD.*:.*\"medicore_pass\"' '${REPO_DIR}/helm/values/'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-127 External Secrets Operator integration verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
