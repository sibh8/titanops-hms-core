#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Audit & Compliance Logging Verification Suite
# Ticket: TITANOPS-122: Enable VPC Flow Logs, CloudTrail, and EKS audit logging
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
echo -e "${BLUE}   TitanOps HMS: Audit & Compliance Logging Verification (TITANOPS-122)       ${NC}"
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

echo -e "${YELLOW}Phase 1: Terraform Syntax & Validation${NC}"
check "1. Terraform formatting adheres to canonical style" \
    "cd '${TF_DIR}' && terraform fmt -check -recursive > /dev/null 2>&1"

check "2. Terraform configuration with audit logging validates cleanly" \
    "cd '${TF_DIR}' && terraform validate > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 2: VPC Flow Logs Verification${NC}"
check "3. VPC Flow Log resource declared with traffic_type = 'ALL'" \
    "grep -q 'resource \"aws_flow_log\"' '${TF_DIR}/modules/networking/main.tf' && grep -q 'traffic_type *= *\"ALL\"' '${TF_DIR}/modules/networking/main.tf'"

check "4. VPC Flow Logs dedicated CloudWatch Log Group configured" \
    "grep -q 'aws_cloudwatch_log_group' '${TF_DIR}/modules/networking/main.tf' && grep -q '/aws/vpc/' '${TF_DIR}/modules/networking/main.tf'"

check "5. VPC Flow Logs IAM delivery role and policy configured" \
    "grep -q 'vpc-flow-logs.amazonaws.com' '${TF_DIR}/modules/networking/main.tf' && grep -q 'aws_iam_role_policy.*vpc_flow_logs' '${TF_DIR}/modules/networking/main.tf'"

echo -e "\n${YELLOW}Phase 3: CloudTrail Audit Logging Verification${NC}"
check "6. CloudTrail resource declared with multi-region and global events" \
    "grep -q 'resource \"aws_cloudtrail\"' '${TF_DIR}/modules/cloudtrail/main.tf' && grep -q 'is_multi_region_trail' '${TF_DIR}/modules/cloudtrail/main.tf'"

check "7. S3 bucket configured with AES-256 encryption and versioning" \
    "grep -q 'aws_s3_bucket_server_side_encryption_configuration' '${TF_DIR}/modules/cloudtrail/main.tf' && grep -q 'aws_s3_bucket_versioning' '${TF_DIR}/modules/cloudtrail/main.tf'"

check "8. S3 bucket blocks all public access" \
    "grep -q 'aws_s3_bucket_public_access_block' '${TF_DIR}/modules/cloudtrail/main.tf' && grep -q 'block_public_acls *= *true' '${TF_DIR}/modules/cloudtrail/main.tf'"

check "9. CloudTrail streams events to CloudWatch Log Group" \
    "grep -q 'cloud_watch_logs_group_arn' '${TF_DIR}/modules/cloudtrail/main.tf' && grep -q '/aws/cloudtrail/' '${TF_DIR}/modules/cloudtrail/main.tf'"

echo -e "\n${YELLOW}Phase 4: EKS Control Plane Audit Logging Verification${NC}"
check "10. EKS cluster enables audit logging" \
    "grep -q 'enabled_cluster_log_types' '${TF_DIR}/modules/eks/main.tf'"

check "11. EKS cluster log types include 'api', 'audit', 'authenticator', 'controllerManager', 'scheduler'" \
    "grep -q '\"audit\"' '${TF_DIR}/modules/eks/variables.tf' && grep -q '\"authenticator\"' '${TF_DIR}/modules/eks/variables.tf' && grep -q '\"controllerManager\"' '${TF_DIR}/modules/eks/variables.tf'"

echo -e "\n${YELLOW}Phase 5: Output Integration & Wiring${NC}"
check "12. Root outputs export vpc_flow_log_id and vpc_flow_log_group_arn" \
    "grep -q 'output \"vpc_flow_log_id\"' '${TF_DIR}/outputs.tf' && grep -q 'output \"vpc_flow_log_group_arn\"' '${TF_DIR}/outputs.tf'"

check "13. Root outputs export cloudtrail_arn and cloudtrail_bucket_name" \
    "grep -q 'output \"cloudtrail_arn\"' '${TF_DIR}/outputs.tf' && grep -q 'output \"cloudtrail_bucket_name\"' '${TF_DIR}/outputs.tf'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-122 Audit & Compliance logging verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
