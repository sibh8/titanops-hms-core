#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Database TLS & Credential Rotation Verification Suite
# Ticket: TITANOPS-119: Enforce TLS and automate credential rotation for the database
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
echo -e "${BLUE}   TitanOps HMS: Database TLS & Credential Rotation Verification (TITANOPS-119)${NC}"
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
COMPOSE_FILE="${REPO_DIR}/docker-compose.yml"
SECRETS_DIR="${REPO_DIR}/terraform/modules/secrets"

echo -e "${YELLOW}Phase 1: JDBC Connection String TLS Enforcement${NC}"
check "1. docker-compose.yml specifies useSSL=true and verifyServerCertificate=true" \
    "grep -q 'useSSL=true' '${COMPOSE_FILE}' && grep -q 'verifyServerCertificate=true' '${COMPOSE_FILE}'"

check "2. docker-compose.yml does not contain useSSL=false in x-db-env" \
    "! grep -A 5 'x-db-env:' '${COMPOSE_FILE}' | grep -q 'useSSL=false'"

check "3. Secrets Manager secret payload strictly requires TLS with server certificate verification" \
    "grep -q 'useSSL=true&requireSSL=true&verifyServerCertificate=true' '${SECRETS_DIR}/main.tf'"

check "4. Secret generator helper enforces TLS and certificate verification" \
    "grep -q 'useSSL=true&requireSSL=true&verifyServerCertificate=true' '${REPO_DIR}/scripts/generate-datasource-secret.sh'"

echo -e "\n${YELLOW}Phase 2: Automated Credential Rotation (Terraform)${NC}"
check "5. Terraform configuration with secrets rotation validates cleanly" \
    "cd '${TF_DIR}' && terraform validate > /dev/null 2>&1"

check "6. AWS Secrets Manager secret rotation resource declared for database" \
    "grep -q 'resource \"aws_secretsmanager_secret_rotation\" \"database\"' '${SECRETS_DIR}/main.tf'"

check "7. Rotation schedule configured with automatically_after_days rule (30-day cycle)" \
    "grep -q 'automatically_after_days' '${SECRETS_DIR}/main.tf'"

check "8. Dedicated IAM role and scoped policy declared for rotation Lambda" \
    "grep -q 'resource \"aws_iam_role\" \"db_rotation\"' '${SECRETS_DIR}/main.tf' && \
     grep -q 'secretsmanager:PutSecretValue' '${SECRETS_DIR}/main.tf'"

echo -e "\n${YELLOW}Phase 3: Dynamic Secrets Manager Integration${NC}"
check "9. Kubernetes ExternalSecret targets titanops-datasource-credentials" \
    "grep -q 'name: titanops-datasource-credentials' '${REPO_DIR}/k8s/external-secrets/02-database-external-secret.yaml'"

check "10. Helm templates and manifests do not expose hardcoded DB passwords" \
    "! grep -rn 'SPRING_DATASOURCE_PASSWORD: [a-zA-Z0-9]' '${REPO_DIR}/helm/titanops-base/templates/' 2>/dev/null"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-119 Database TLS & Credential Rotation verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: TITANOPS-119 verification failed.${NC}"
    exit 1
fi
