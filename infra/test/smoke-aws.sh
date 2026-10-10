#!/usr/bin/env bash
# ============================================================================
# AWS smoke test + CIS benchmark checks for a DEPLOYED TitanOps HMS stack.
#
# Verifies the real AWS resources against the stack's intent and the CIS
# Level 1 controls we baked into the Terraform modules.
#
# Requirements:
#   - stack already applied for an AWS environment (default: dev)
#   - aws CLI v2 configured with read access
#   - jq
#   - terraform (to read outputs for resource identifiers)
#
# Usage:  ./smoke-aws.sh [environment]     (default: dev)
#
# Exit 0 = all checks passed, 1 = one or more failed.
# ============================================================================
set -uo pipefail

ENVIRONMENT="${1:-dev}"

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(dirname "$TEST_DIR")"
STACK_DIR="$INFRA_ROOT/infra-stack/hms-core-stack"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; [[ -n "${2:-}" ]] && echo -e "         ${RED}$2${NC}"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}[SKIP]${NC} $1"; [[ -n "${2:-}" ]] && echo -e "         ${YELLOW}$2${NC}"; SKIP=$((SKIP + 1)); }

# assert_eq <expected> <actual> <check-name>
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3" "expected '$1', got '$2'"; fi; }
# assert_true <value> <check-name>  (value must be the literal "true")
assert_true() { if [[ "$1" == "true" ]]; then pass "$2"; else fail "$2" "got '$1'"; fi; }

for tool in aws jq terraform; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Required tool '$tool' not found on PATH." >&2; exit 1; }
done

tfout() { terraform -chdir="$STACK_DIR" output -raw "$1" 2>/dev/null; }

echo -e "${CYAN}== TitanOps HMS - AWS smoke & CIS checks ==${NC}"
echo -e "   environment: $ENVIRONMENT\n"

TARGET="$(tfout target)"
if [[ "$TARGET" != "aws" ]]; then
  echo -e "${RED}Stack target is '$TARGET', not 'aws'. Apply the AWS env first:${NC}" >&2
  echo "  infra/scripts/hms.sh $ENVIRONMENT apply" >&2
  exit 1
fi

REGION="$(tfout region)";            export AWS_DEFAULT_REGION="$REGION"
VPC_ID="$(tfout vpc_id)"
CLUSTER="$(tfout cluster_name)"
RDS_ID="$(tfout rds_identifier)"

echo "   region=$REGION vpc=$VPC_ID cluster=$CLUSTER rds=$RDS_ID"
echo

# ---------------------------------------------------------------------------
echo "VPC / networking:"
# Smoke: VPC exists and is available
state="$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].State' --output text 2>/dev/null)"
assert_eq "available" "$state" "VPC exists and is available"

# CIS 3.9: VPC flow logging enabled
fl="$(aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$VPC_ID" --query 'length(FlowLogs)' --output text 2>/dev/null)"
if [[ "${fl:-0}" -ge 1 ]]; then pass "CIS 3.9 - VPC flow logs enabled"; else fail "CIS 3.9 - VPC flow logs enabled" "no flow logs on $VPC_ID"; fi

# CIS 5.3: default security group restricts all traffic (no rules)
dsg="$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" --query 'SecurityGroups[0].[length(IpPermissions),length(IpPermissionsEgress)]' --output text 2>/dev/null)"
if [[ "$dsg" == "0	0" ]]; then pass "CIS 5.3 - default SG has no in/egress rules"; else fail "CIS 5.3 - default SG has no in/egress rules" "rules: $dsg"; fi

# CIS 5.2: no security group allows 0.0.0.0/0 to port 22 (SSH)
open_ssh="$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[?IpPermissions[?FromPort<=\`22\` && ToPort>=\`22\` && IpRanges[?CidrIp=='0.0.0.0/0']]].GroupId" --output text 2>/dev/null)"
if [[ -z "$open_ssh" ]]; then pass "CIS 5.2 - no SG opens SSH (22) to the world"; else fail "CIS 5.2 - no SG opens SSH (22) to the world" "offending: $open_ssh"; fi

# ---------------------------------------------------------------------------
echo "EKS:"
cstatus="$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.status' --output text 2>/dev/null)"
assert_eq "ACTIVE" "$cstatus" "EKS cluster is ACTIVE"

# CIS EKS 2.1.1: control plane audit logging enabled
audit="$(aws eks describe-cluster --name "$CLUSTER" --query "cluster.logging.clusterLogging[?enabled].types[]" --output text 2>/dev/null)"
if echo "$audit" | grep -q "audit"; then pass "CIS EKS 2.1.1 - audit logging enabled"; else fail "CIS EKS 2.1.1 - audit logging enabled" "enabled: $audit"; fi

# CIS EKS 3.x: secrets envelope encryption with KMS
enc="$(aws eks describe-cluster --name "$CLUSTER" --query "length(cluster.encryptionConfig)" --output text 2>/dev/null)"
if [[ "${enc:-0}" -ge 1 ]]; then pass "CIS EKS - secrets encrypted with KMS"; else skip "CIS EKS - secrets encrypted with KMS" "no encryptionConfig (set kms_key_arn to enable)"; fi

# CIS EKS 5.4.1: private API endpoint (public access disabled)
pub="$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.endpointPublicAccess' --output text 2>/dev/null)"
assert_eq "False" "$pub" "CIS EKS 5.4.1 - API endpoint public access disabled"

# CIS: nodes enforce IMDSv2 (http_tokens=required) on their launch templates
lt_ids="$(aws ec2 describe-launch-templates --query "LaunchTemplates[?starts_with(LaunchTemplateName, '${CLUSTER}')].LaunchTemplateId" --output text 2>/dev/null)"
imdsv2_ok="true"
for lt in $lt_ids; do
  tok="$(aws ec2 describe-launch-template-versions --launch-template-id "$lt" --versions '$Latest' \
    --query 'LaunchTemplateVersions[0].LaunchTemplateData.MetadataOptions.HttpTokens' --output text 2>/dev/null)"
  [[ "$tok" == "required" ]] || imdsv2_ok="false"
done
if [[ -n "$lt_ids" ]]; then assert_true "$imdsv2_ok" "CIS - worker nodes enforce IMDSv2"; else skip "CIS - worker nodes enforce IMDSv2" "no launch templates found"; fi

# ---------------------------------------------------------------------------
echo "RDS:"
rstatus="$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)"
assert_eq "available" "$rstatus" "RDS instance is available"

# CIS RDS: encryption at rest
enc="$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query 'DBInstances[0].StorageEncrypted' --output text 2>/dev/null)"
assert_eq "True" "$enc" "CIS RDS - storage encrypted at rest"

# CIS RDS: not publicly accessible
pub="$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query 'DBInstances[0].PubliclyAccessible' --output text 2>/dev/null)"
assert_eq "False" "$pub" "CIS RDS - not publicly accessible"

# CIS RDS: multi-AZ for availability
maz="$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query 'DBInstances[0].MultiAZ' --output text 2>/dev/null)"
assert_eq "True" "$maz" "CIS RDS - Multi-AZ enabled"

# CIS RDS: automated backups retained
bk="$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query 'DBInstances[0].BackupRetentionPeriod' --output text 2>/dev/null)"
if [[ "${bk:-0}" -ge 1 ]]; then pass "CIS RDS - automated backups enabled ($bk days)"; else fail "CIS RDS - automated backups enabled" "retention: $bk"; fi

# CIS RDS: deletion protection on
dp="$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --query 'DBInstances[0].DeletionProtection' --output text 2>/dev/null)"
assert_eq "True" "$dp" "CIS RDS - deletion protection enabled"

# ---------------------------------------------------------------------------
echo "ECR:"
# CIS: scan-on-push + immutable tags for each repo
repos="$(aws ecr describe-repositories --query 'repositories[].repositoryName' --output text 2>/dev/null)"
ecr_scan_ok="true"; ecr_immut_ok="true"; checked=0
for r in $repos; do
  [[ "$r" == *"titanops-hms/"* ]] || continue
  checked=$((checked + 1))
  s="$(aws ecr describe-repositories --repository-names "$r" --query 'repositories[0].imageScanningConfiguration.scanOnPush' --output text 2>/dev/null)"
  i="$(aws ecr describe-repositories --repository-names "$r" --query 'repositories[0].imageTagMutability' --output text 2>/dev/null)"
  [[ "$s" == "True" ]] || ecr_scan_ok="false"
  [[ "$i" == "IMMUTABLE" ]] || ecr_immut_ok="false"
done
if [[ "$checked" -gt 0 ]]; then
  assert_true "$ecr_scan_ok" "CIS ECR - scan on push enabled ($checked repos)"
  assert_true "$ecr_immut_ok" "CIS ECR - image tags immutable ($checked repos)"
else
  skip "CIS ECR - repo checks" "no titanops-hms repositories found"
fi

# ---------------------------------------------------------------------------
echo "IAM / OIDC:"
oidc="$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')] | length(@)" --output text 2>/dev/null)"
if [[ "${oidc:-0}" -ge 1 ]]; then pass "CIS IAM - GitHub OIDC provider present (no static keys)"; else fail "CIS IAM - GitHub OIDC provider present" "not found"; fi

# ---------------------------------------------------------------------------
echo "Optional security features (as configured):"
# These only exist when enabled in config.yaml; report their live state.
gd="$(aws guardduty list-detectors --query 'length(DetectorIds)' --output text 2>/dev/null || echo 0)"
if [[ "${gd:-0}" -ge 1 ]]; then pass "CIS - GuardDuty detector enabled"; else skip "CIS - GuardDuty detector" "disabled in config (feature off)"; fi

sh="$(aws securityhub get-enabled-standards --query 'length(StandardsSubscriptions)' --output text 2>/dev/null || echo 0)"
if [[ "${sh:-0}" -ge 1 ]]; then pass "CIS - Security Hub CIS standard subscribed"; else skip "CIS - Security Hub" "disabled in config (feature off)"; fi

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}== Results ==${NC}"
echo -e "   ${GREEN}Passed: $PASS${NC}   ${YELLOW}Skipped: $SKIP${NC}   ${RED}Failed: $FAIL${NC}"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
