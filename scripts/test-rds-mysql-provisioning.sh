#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: RDS MySQL Provisioning Automated Verification Suite
# Ticket: TITANOPS-67: Provision RDS MySQL via Terraform to replace docker-compose MySQL
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
echo -e "${BLUE}   TitanOps HMS: RDS MySQL Terraform Verification Suite (TITANOPS-67)         ${NC}"
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

check "2. Terraform root and RDS modules pass validation" \
    "cd '${TF_DIR}' && terraform validate > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 2: Database Configuration & Engine Compatibility${NC}"
check "3. RDS instance is configured with engine 'mysql'" \
    "grep -q 'engine *= *\"mysql\"' '${TF_DIR}/modules/rds/main.tf'"

check "4. MySQL engine version is 8.0.x" \
    "grep -q '8.0' '${TF_DIR}/modules/rds/variables.tf'"

check "5. Database name defaults to 'medicore_hms'" \
    "grep -q 'medicore_hms' '${TF_DIR}/modules/rds/variables.tf'"

check "6. Master admin username defaults to 'medicore'" \
    "grep -q 'medicore' '${TF_DIR}/modules/rds/variables.tf'"

echo -e "\n${YELLOW}Phase 3: Network Isolation & Security Group Rules${NC}"
check "7. RDS subnet group uses private subnets" \
    "grep -q 'subnet_ids *= *var.private_subnet_ids' '${TF_DIR}/modules/rds/main.tf'"

check "8. RDS security group allows port 3306 ingress from EKS cluster SG" \
    "grep -A 8 'Allow MySQL traffic from EKS worker nodes' '${TF_DIR}/modules/rds/main.tf' | grep -q 'var.eks_cluster_security_group_id'"

check "9. RDS security group restricts MySQL access (no open 0.0.0.0/0 ingress)" \
    "! grep -B 2 -A 8 'ingress' '${TF_DIR}/modules/rds/main.tf' | grep 'from_port *= *3306' -A 4 | grep -q '\"0.0.0.0/0\"'"

echo -e "\n${YELLOW}Phase 4: Outputs & Spring Boot Microservices Integration${NC}"
check "10. Module exports DB endpoint output" \
    "grep -q 'output \"db_endpoint\"' '${TF_DIR}/modules/rds/outputs.tf'"

check "11. Module exports DB address hostname output" \
    "grep -q 'output \"db_address\"' '${TF_DIR}/modules/rds/outputs.tf'"

check "12. Module exports DB port output" \
    "grep -q 'output \"db_port\"' '${TF_DIR}/modules/rds/outputs.tf'"

check "13. Module exports standard Spring Boot JDBC connection URL" \
    "grep -q 'output \"jdbc_connection_url\"' '${TF_DIR}/modules/rds/outputs.tf'"

check "14. Root Terraform exports rds_jdbc_connection_url" \
    "grep -q 'output \"rds_jdbc_connection_url\"' '${TF_DIR}/outputs.tf'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-67 RDS MySQL Terraform provisioning verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
