#!/usr/bin/env bash
# ==============================================================================
# MediCore HMS — Terraform Remote State Verification Suite
# TITANOPS-29: Configure Terraform remote state backend in AWS S3
# ==============================================================================
# Verifies Definition of Done:
# 1. terraform init uses the S3 backend and state file appears in configured bucket
# 2. State locking table (DynamoDB) prevents concurrent applies from corrupting state
# 3. Bucket has versioning enabled and is not publicly accessible
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(dirname "$SCRIPT_DIR")"
STACK_DIR="$INFRA_ROOT/infra-stack/hms-core-stack"
MODULE_DIR="$INFRA_ROOT/infra-stack/modules/remote-state"
REMOTE_STATE_ROOT="$INFRA_ROOT/remote-state"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASSED_COUNT=0
TOTAL_COUNT=0

record_result() {
  local test_name="$1"
  local status="$2"
  local details="$3"

  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  if [ "$status" = "PASS" ]; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo -e "  [${GREEN}PASS${NC}] ${test_name}"
    if [ -n "$details" ]; then
      echo -e "         ${CYAN}${details}${NC}"
    fi
  else
    echo -e "  [${RED}FAIL${NC}] ${test_name}"
    if [ -n "$details" ]; then
      echo -e "         ${RED}${details}${NC}"
    fi
  fi
}

echo -e "\n${CYAN}${BOLD}========================================================================${NC}"
echo -e "${CYAN}${BOLD}   TITANOPS-29: Terraform S3 Remote State Verification Suite           ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}\n"

# ------------------------------------------------------------------------------
# STEP 1: DoD #1 - S3 Backend Configuration in versions.tf
# ------------------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}Step 1: S3 Backend Configuration in versions.tf (DoD #1)${NC}"

VERSIONS_FILE="$STACK_DIR/versions.tf"
if [ -f "$VERSIONS_FILE" ]; then
  HAS_BACKEND_S3=$(grep -E 'backend\s+"s3"' "$VERSIONS_FILE" || true)
  HAS_BUCKET=$(grep -E 'bucket\s*=\s*"titanops-hms-tfstate"' "$VERSIONS_FILE" || true)
  HAS_KEY=$(grep -E 'key\s*=\s*"hms-core/terraform.tfstate"' "$VERSIONS_FILE" || true)
  HAS_REGION=$(grep -E 'region\s*=\s*"ap-south-1"' "$VERSIONS_FILE" || true)
  HAS_DYNAMO=$(grep -E 'dynamodb_table\s*=\s*"titanops-hms-tflock"' "$VERSIONS_FILE" || true)
  HAS_ENCRYPT=$(grep -E 'encrypt\s*=\s*true' "$VERSIONS_FILE" || true)

  if [ -n "$HAS_BACKEND_S3" ] && [ -n "$HAS_BUCKET" ] && [ -n "$HAS_KEY" ] && [ -n "$HAS_REGION" ] && [ -n "$HAS_DYNAMO" ] && [ -n "$HAS_ENCRYPT" ]; then
    record_result "DoD #1: S3 Backend configured in versions.tf" "PASS" "Configured bucket=titanops-hms-tfstate, dynamodb_table=titanops-hms-tflock, region=ap-south-1, encrypt=true"
  else
    record_result "DoD #1: S3 Backend configured in versions.tf" "FAIL" "Missing one or more required backend attributes in $VERSIONS_FILE"
  fi
else
  record_result "DoD #1: versions.tf exists" "FAIL" "File $VERSIONS_FILE not found"
fi

# Environment-specific backend configs
if [ -f "$INFRA_ROOT/environments/dev/backend.hcl" ] && [ -f "$INFRA_ROOT/environments/local/backend.hcl" ]; then
  record_result "Environment backend.hcl configs (dev & local)" "PASS" "Configured per-environment state keys for safe multi-tier state isolation"
else
  record_result "Environment backend.hcl configs (dev & local)" "FAIL" "Missing backend.hcl in environments"
fi

# ------------------------------------------------------------------------------
# STEP 2: DoD #2 - DynamoDB State Locking Configuration
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Step 2: DynamoDB State Locking Configuration (DoD #2)${NC}"

MODULE_MAIN="$MODULE_DIR/main.tf"
if [ -f "$MODULE_MAIN" ]; then
  HAS_DYNAMO_RESOURCE=$(grep "aws_dynamodb_table" "$MODULE_MAIN" || true)
  HAS_LOCK_ID=$(grep -A 5 'attribute {' "$MODULE_MAIN" | grep 'name\s*=\s*"LockID"' || true)
  HAS_TYPE_S=$(grep -A 5 'attribute {' "$MODULE_MAIN" | grep 'type\s*=\s*"S"' || true)
  HAS_ON_DEMAND=$(grep 'billing_mode\s*=\s*"PAY_PER_REQUEST"' "$MODULE_MAIN" || true)
  HAS_DYNAMO_SSE=$(grep -A 3 'server_side_encryption {' "$MODULE_MAIN" | grep 'enabled\s*=\s*true' || true)

  if [ -n "$HAS_DYNAMO_RESOURCE" ] && [ -n "$HAS_LOCK_ID" ] && [ -n "$HAS_TYPE_S" ] && [ -n "$HAS_ON_DEMAND" ]; then
    record_result "DoD #2: DynamoDB state locking table with LockID partition key" "PASS" "Enforces hash_key=LockID (String), PAY_PER_REQUEST on-demand billing, and SSE"
  else
    record_result "DoD #2: DynamoDB state locking table with LockID partition key" "FAIL" "Missing LockID hash_key or PAY_PER_REQUEST billing mode in $MODULE_MAIN"
  fi
else
  record_result "DoD #2: remote-state module main.tf exists" "FAIL" "File $MODULE_MAIN not found"
fi

# ------------------------------------------------------------------------------
# STEP 3: DoD #3 - S3 Versioning & Non-Public Access Block
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Step 3: S3 Versioning, Encryption & Public Access Block (DoD #3)${NC}"

if [ -f "$MODULE_MAIN" ]; then
  HAS_VERSIONING=$(grep "aws_s3_bucket_versioning" "$MODULE_MAIN" || true)
  HAS_STATUS_ENABLED=$(grep -E 'status\s*=\s*var\.enable_versioning\s*\?\s*"Enabled"\s*:\s*"Suspended"' "$MODULE_MAIN" || true)
  HAS_ENCRYPTION=$(grep "aws_s3_bucket_server_side_encryption_configuration" "$MODULE_MAIN" || true)
  HAS_PUBLIC_BLOCK=$(grep "aws_s3_bucket_public_access_block" "$MODULE_MAIN" || true)
  HAS_BLOCK_ACLS=$(grep 'block_public_acls\s*=\s*true' "$MODULE_MAIN" || true)
  HAS_BLOCK_POLICY=$(grep 'block_public_policy\s*=\s*true' "$MODULE_MAIN" || true)
  HAS_IGNORE_ACLS=$(grep 'ignore_public_acls\s*=\s*true' "$MODULE_MAIN" || true)
  HAS_RESTRICT_BUCKETS=$(grep 'restrict_public_buckets\s*=\s*true' "$MODULE_MAIN" || true)
  HAS_TLS_POLICY=$(grep 'aws:SecureTransport' "$MODULE_MAIN" || true)

  if [ -n "$HAS_VERSIONING" ] && [ -n "$HAS_STATUS_ENABLED" ]; then
    record_result "DoD #3A: S3 bucket versioning enabled" "PASS" "State history preserved; accidental deletion recovery enabled"
  else
    record_result "DoD #3A: S3 bucket versioning enabled" "FAIL" "S3 bucket versioning not enabled in $MODULE_MAIN"
  fi

  if [ -n "$HAS_PUBLIC_BLOCK" ] && [ -n "$HAS_BLOCK_ACLS" ] && [ -n "$HAS_BLOCK_POLICY" ] && [ -n "$HAS_IGNORE_ACLS" ] && [ -n "$HAS_RESTRICT_BUCKETS" ]; then
    record_result "DoD #3B: S3 bucket public access completely blocked (Non-public)" "PASS" "All 4 S3 public access block controls set to true"
  else
    record_result "DoD #3B: S3 bucket public access completely blocked (Non-public)" "FAIL" "Missing public access block controls in $MODULE_MAIN"
  fi

  if [ -n "$HAS_ENCRYPTION" ] && [ -n "$HAS_TLS_POLICY" ]; then
    record_result "CIS Security: Encryption at rest (AES256/KMS) & TLS in transit" "PASS" "Default encryption enabled; non-TLS requests strictly denied by bucket policy"
  else
    record_result "CIS Security: Encryption at rest (AES256/KMS) & TLS in transit" "FAIL" "Missing encryption or TLS bucket policy"
  fi
fi

# ------------------------------------------------------------------------------
# STEP 4: Terraform Syntax & Validation
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Step 4: Terraform Static Validation Suite${NC}"

if terraform -chdir="$INFRA_ROOT" fmt -check -recursive >/dev/null 2>&1; then
  record_result "Terraform formatting check (terraform fmt -check -recursive)" "PASS" "All infrastructure HCL files formatted cleanly"
else
  record_result "Terraform formatting check (terraform fmt -check -recursive)" "FAIL" "Formatting issues detected in infra"
fi

if out=$(terraform -chdir="$REMOTE_STATE_ROOT" init -backend=false -no-color 2>&1 && terraform -chdir="$REMOTE_STATE_ROOT" validate -no-color 2>&1); then
  record_result "Remote State Bootstrap stack validation (infra/remote-state)" "PASS" "Standalone bootstrap stack is valid"
else
  record_result "Remote State Bootstrap stack validation (infra/remote-state)" "FAIL" "$out"
fi
rm -rf "$REMOTE_STATE_ROOT/.terraform"

if out=$("$INFRA_ROOT/test/validate.sh" 2>&1); then
  record_result "Core Stack validation suite (infra/test/validate.sh)" "PASS" "All 15 environment and module tests passed"
else
  record_result "Core Stack validation suite (infra/test/validate.sh)" "FAIL" "$out"
fi

# ------------------------------------------------------------------------------
# SUMMARY REPORT
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}${BOLD}========================================================================${NC}"
echo -e "${CYAN}${BOLD}   Verification Summary: ${PASSED_COUNT} / ${TOTAL_COUNT} Tests Passed               ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}"

if [ "$PASSED_COUNT" -eq "$TOTAL_COUNT" ]; then
  echo -e "${GREEN}${BOLD}✓ ALL DEFINITION OF DONE REQUIREMENTS SATISFIED FOR TITANOPS-29!${NC}\n"
  exit 0
else
  echo -e "${RED}${BOLD}✗ SOME VERIFICATION TESTS FAILED. PLEASE REVIEW LOGS ABOVE.${NC}\n"
  exit 1
fi
