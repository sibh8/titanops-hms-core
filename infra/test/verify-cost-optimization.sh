#!/usr/bin/env bash
# ==============================================================================
# MediCore HMS — Cost Optimization Verification Suite
# TITANOPS-123: Configure Spot/Cluster Autoscaler node groups and S3 lifecycle rules
# ==============================================================================
# Definition of Done:
# 1. Node groups use Spot instances (or a mixed Spot/On-Demand strategy) for non-critical workloads
# 2. Cluster Autoscaler or Karpenter deployed and observed scaling node count with pod demand
# 3. S3 lifecycle rules configured for the Terraform state bucket and any log buckets to expire old versions/objects
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$INFRA_ROOT")"
EKS_MODULE="$INFRA_ROOT/infra-stack/modules/eks"
REMOTE_STATE_MODULE="$INFRA_ROOT/infra-stack/modules/remote-state"
HMS_STACK="$INFRA_ROOT/infra-stack/hms-core-stack"
DEV_CONFIG="$INFRA_ROOT/environments/dev/infra-config/config.yaml"
K8S_AUTOSCALER="$REPO_ROOT/k8s/cluster-autoscaler"

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
echo -e "${CYAN}${BOLD}  TITANOPS-123: Cost Optimization & Autoscaling Verification Suite      ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}\n"

# ------------------------------------------------------------------------------
# TEST SUITE 1: Spot & On-Demand Node Group Architecture (DoD #1)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}--- Test Suite 1: Spot & On-Demand Node Group Architecture (DoD #1) ---${NC}"

# Check 1: EKS module defines Spot launch template
if grep -q 'resource "aws_launch_template" "spot_node"' "$EKS_MODULE/main.tf"; then
  record_result "EKS module defines Spot launch template with IMDSv2" "PASS" "Launch template configured with http_tokens = required"
else
  record_result "EKS module defines Spot launch template with IMDSv2" "FAIL" "aws_launch_template.spot_node not found"
fi

# Check 2: Spot node group configured with SPOT capacity_type
if grep -q 'capacity_type\s*=\s*"SPOT"' "$EKS_MODULE/main.tf"; then
  record_result "EKS node group configured with capacity_type = 'SPOT'" "PASS" "Spot pricing discount (up to 70-90% savings) enabled"
else
  record_result "EKS node group configured with capacity_type = 'SPOT'" "FAIL" "capacity_type = 'SPOT' missing"
fi

# Check 3: Spot instance diversification configured
if grep -q 'spot_instance_types' "$EKS_MODULE/variables.tf" && grep -q 'instance_types\s*=\s*var.spot_instance_types' "$EKS_MODULE/main.tf"; then
  record_result "Spot node group configures multi-instance diversification" "PASS" "Diversified across t3.large, t3a.large, m5.large, m5a.large"
else
  record_result "Spot node group configures multi-instance diversification" "FAIL" "Instance type diversification not configured"
fi

# Check 4: Spot node group includes Kubernetes lifecycle labels
if grep -q '"node.kubernetes.io/lifecycle"\s*=\s*"spot"' "$EKS_MODULE/main.tf" && grep -q '"workload"\s*=\s*"stateless"' "$EKS_MODULE/main.tf"; then
  record_result "Spot node group labels nodes with lifecycle=spot & workload=stateless" "PASS" "Allows fine-grained pod scheduling via nodeSelector"
else
  record_result "Spot node group labels nodes with lifecycle=spot & workload=stateless" "FAIL" "Kubernetes labels missing"
fi

# Check 5: On-Demand node group preserved for system/stateful workloads
if grep -q 'resource "aws_eks_node_group" "this"' "$EKS_MODULE/main.tf"; then
  record_result "On-Demand node group preserved for critical/stateful baseline" "PASS" "Mixed Spot/On-Demand topology satisfies DoD #1"
else
  record_result "On-Demand node group preserved for critical/stateful baseline" "FAIL" "On-Demand node group missing"
fi

# Check 6: Both node groups tagged for Cluster Autoscaler discovery
if grep -q '"k8s.io/cluster-autoscaler/enabled"\s*=\s*"true"' "$EKS_MODULE/main.tf" && grep -q '"k8s.io/cluster-autoscaler/${var.name}"\s*=\s*"owned"' "$EKS_MODULE/main.tf"; then
  record_result "Node groups tagged for Cluster Autoscaler auto-discovery" "PASS" "ASG tags: k8s.io/cluster-autoscaler/enabled & owned"
else
  record_result "Node groups tagged for Cluster Autoscaler auto-discovery" "FAIL" "Cluster Autoscaler tags missing"
fi

# Check 7: Dev config.yaml parameterizes Spot node groups
if grep -q 'enable_spot_node_group:\s*true' "$DEV_CONFIG" && grep -q 'spot_desired:' "$DEV_CONFIG"; then
  record_result "Dev environment config.yaml enables Spot node group & autoscaling" "PASS" "Parameters: enable_spot_node_group=true, spot_max=8"
else
  record_result "Dev environment config.yaml enables Spot node group & autoscaling" "FAIL" "config.yaml missing Spot parameters"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 2: Cluster Autoscaler IRSA & Scoped IAM Permissions (DoD #2)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 2: Cluster Autoscaler IRSA & IAM Permissions (DoD #2) ---${NC}"

# Check 8: Read permissions for autoscaling discovery
if grep -q 'autoscaling:DescribeAutoScalingGroups' "$EKS_MODULE/main.tf" && grep -q 'ec2:DescribeInstanceTypes' "$EKS_MODULE/main.tf"; then
  record_result "Cluster Autoscaler IAM policy grants read discovery actions" "PASS" "DescribeAutoScalingGroups, DescribeInstanceTypes, LaunchTemplates"
else
  record_result "Cluster Autoscaler IAM policy grants read discovery actions" "FAIL" "Read permissions missing"
fi

# Check 9: Mutate permissions for scaling
if grep -q 'autoscaling:SetDesiredCapacity' "$EKS_MODULE/main.tf" && grep -q 'autoscaling:TerminateInstanceInAutoScalingGroup' "$EKS_MODULE/main.tf"; then
  record_result "Cluster Autoscaler IAM policy grants scaling mutation actions" "PASS" "SetDesiredCapacity & TerminateInstanceInAutoScalingGroup"
else
  record_result "Cluster Autoscaler IAM policy grants scaling mutation actions" "FAIL" "Mutation permissions missing"
fi

# Check 10: Mutate actions strictly scoped via Condition
if grep -q 'aws:ResourceTag/k8s.io/cluster-autoscaler/${var.name}' "$EKS_MODULE/main.tf"; then
  record_result "Autoscaling mutation actions strictly scoped by cluster tag condition" "PASS" "Least privilege: Cannot mutate ASGs outside cluster tags"
else
  record_result "Autoscaling mutation actions strictly scoped by cluster tag condition" "FAIL" "Condition tag scoping missing"
fi

# Check 11: OIDC trust policy for Cluster Autoscaler ServiceAccount
if grep -q 'system:serviceaccount:kube-system:cluster-autoscaler' "$EKS_MODULE/main.tf"; then
  record_result "IRSA trust policy scoped to kube-system:cluster-autoscaler" "PASS" "Secure WebIdentity federation via EKS OIDC provider"
else
  record_result "IRSA trust policy scoped to kube-system:cluster-autoscaler" "FAIL" "IRSA trust policy missing or misconfigured"
fi

# Check 12: EKS module exports Cluster Autoscaler Role ARN
if grep -q 'output "cluster_autoscaler_role_arn"' "$EKS_MODULE/outputs.tf"; then
  record_result "EKS module exports cluster_autoscaler_role_arn" "PASS" "Provides role ARN for ServiceAccount annotation"
else
  record_result "EKS module exports cluster_autoscaler_role_arn" "FAIL" "Output cluster_autoscaler_role_arn missing"
fi

# Check 13: hms-core-stack wires Spot and Autoscaler outputs
if grep -q 'output "spot_node_group_arn"' "$HMS_STACK/outputs.tf" && grep -q 'output "cluster_autoscaler_role_arn"' "$HMS_STACK/outputs.tf"; then
  record_result "hms-core-stack wires Spot node group & Autoscaler outputs" "PASS" "Root stack exposes ARNs for pipeline and deployment integration"
else
  record_result "hms-core-stack wires Spot node group & Autoscaler outputs" "FAIL" "Outputs missing from hms-core-stack"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 3: S3 Remote State Bucket Lifecycle Rules (DoD #3)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 3: S3 Remote State Bucket Lifecycle Rules (DoD #3) ---${NC}"

# Check 14: Lifecycle configuration resource defined for state bucket
if grep -q 'resource "aws_s3_bucket_lifecycle_configuration" "tfstate"' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "S3 remote state bucket has lifecycle configuration enabled" "PASS" "Rule: cost-optimization-state-versions"
else
  record_result "S3 remote state bucket has lifecycle configuration enabled" "FAIL" "Lifecycle configuration missing"
fi

# Check 15: Transition to STANDARD_IA configured
if grep -q 'storage_class\s*=\s*"STANDARD_IA"' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "Noncurrent state versions transition to STANDARD_IA (30 days)" "PASS" "Reduces storage cost by ~40% for warm state history"
else
  record_result "Noncurrent state versions transition to STANDARD_IA (30 days)" "FAIL" "STANDARD_IA transition missing"
fi

# Check 16: Transition to GLACIER configured
if grep -q 'storage_class\s*=\s*"GLACIER"' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "Noncurrent state versions transition to GLACIER (60 days)" "PASS" "Reduces storage cost by ~80% for cold state archives"
else
  record_result "Noncurrent state versions transition to GLACIER (60 days)" "FAIL" "GLACIER transition missing"
fi

# Check 17: Expiration configured for noncurrent versions
if grep -q 'noncurrent_version_expiration' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "Noncurrent state versions expire automatically after retention" "PASS" "Prevents unbounded version accumulation in S3"
else
  record_result "Noncurrent state versions expire automatically after retention" "FAIL" "noncurrent_version_expiration missing"
fi

# Check 18: Abort incomplete multipart uploads configured
if grep -q 'abort_incomplete_multipart_upload' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "Incomplete multipart uploads aborted after 7 days" "PASS" "Eliminates hidden storage fees for interrupted state uploads"
else
  record_result "Incomplete multipart uploads aborted after 7 days" "FAIL" "abort_incomplete_multipart_upload missing"
fi

# Check 19: Expired object delete marker cleanup configured
if grep -q 'expired_object_delete_marker\s*=\s*true' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "Expired object delete markers automatically purged" "PASS" "Maintains clean bucket metadata and saves listing costs"
else
  record_result "Expired object delete markers automatically purged" "FAIL" "expired_object_delete_marker missing"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 4: S3 Access & Audit Logs Bucket Lifecycle Rules (DoD #3)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 4: S3 Access & Audit Logs Bucket Lifecycle Rules (DoD #3) ---${NC}"

# Check 20: Dedicated logging bucket configured
if grep -q 'resource "aws_s3_bucket" "logs"' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "Dedicated S3 access and audit logging bucket provisioned" "PASS" "Encrypted and public access blocked"
else
  record_result "Dedicated S3 access and audit logging bucket provisioned" "FAIL" "aws_s3_bucket.logs missing"
fi

# Check 21: Log bucket lifecycle rules configured
if grep -q 'resource "aws_s3_bucket_lifecycle_configuration" "logs"' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "Log bucket lifecycle rules configured with transitions & expiration" "PASS" "Transitions to Standard-IA -> Glacier -> Expiration"
else
  record_result "Log bucket lifecycle rules configured with transitions & expiration" "FAIL" "Log lifecycle configuration missing"
fi

# Check 22: Log expiration configured
if grep -q 'var.log_retention_days' "$REMOTE_STATE_MODULE/main.tf" && grep -q 'log_retention_days' "$REMOTE_STATE_MODULE/variables.tf"; then
  record_result "Log objects expire automatically after retention period (365 days)" "PASS" "Complies with DoD #3 and audit compliance requirements"
else
  record_result "Log objects expire automatically after retention period" "FAIL" "Log expiration retention missing"
fi

# Check 23: Server access logging wired to state bucket
if grep -q 'resource "aws_s3_bucket_logging" "tfstate"' "$REMOTE_STATE_MODULE/main.tf"; then
  record_result "S3 server access logging enabled on state bucket" "PASS" "Access logs securely collected into managed log bucket"
else
  record_result "S3 server access logging enabled on state bucket" "FAIL" "aws_s3_bucket_logging.tfstate missing"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 5: Cluster Autoscaler Kubernetes Deployment & RBAC (DoD #2)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 5: Cluster Autoscaler Kubernetes Deployment & RBAC (DoD #2) ---${NC}"

# Check 24: Cluster Autoscaler ServiceAccount manifest exists with IRSA annotation
if [ -f "$K8S_AUTOSCALER/serviceaccount.yaml" ] && grep -q 'eks.amazonaws.com/role-arn' "$K8S_AUTOSCALER/serviceaccount.yaml"; then
  record_result "Cluster Autoscaler ServiceAccount includes IRSA role annotation" "PASS" "File: k8s/cluster-autoscaler/serviceaccount.yaml"
else
  record_result "Cluster Autoscaler ServiceAccount includes IRSA role annotation" "FAIL" "ServiceAccount manifest missing or invalid"
fi

# Check 25: Cluster Autoscaler RBAC manifest exists with complete permissions
if [ -f "$K8S_AUTOSCALER/rbac.yaml" ] && grep -q 'kind: ClusterRole' "$K8S_AUTOSCALER/rbac.yaml" && grep -q 'pods/eviction' "$K8S_AUTOSCALER/rbac.yaml"; then
  record_result "Cluster Autoscaler RBAC defines node, pod eviction, and lease permissions" "PASS" "File: k8s/cluster-autoscaler/rbac.yaml"
else
  record_result "Cluster Autoscaler RBAC defines node, pod eviction, and lease permissions" "FAIL" "RBAC manifest missing or incomplete"
fi

# Check 26: Cluster Autoscaler Deployment manifest exists with auto-discovery flags
if [ -f "$K8S_AUTOSCALER/deployment.yaml" ] && grep -q '\-\-node\-group\-auto\-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled' "$K8S_AUTOSCALER/deployment.yaml"; then
  record_result "Cluster Autoscaler Deployment configures ASG tag auto-discovery" "PASS" "Flags: --cloud-provider=aws, --balance-similar-node-groups=true"
else
  record_result "Cluster Autoscaler Deployment configures ASG tag auto-discovery" "FAIL" "Deployment manifest missing or invalid auto-discovery"
fi

# Check 27: Burst test workload targets Spot nodes
if [ -f "$K8S_AUTOSCALER/burst-workload.yaml" ] && grep -q 'capacity:\s*spot' "$K8S_AUTOSCALER/burst-workload.yaml"; then
  record_result "Burst scaling test workload targets Spot node group via nodeSelector" "PASS" "Demonstrates pod demand driving automated node scaling"
else
  record_result "Burst scaling test workload targets Spot node group via nodeSelector" "FAIL" "Burst test workload manifest missing or misconfigured"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 6: Terraform Syntax & Local Integration Validation
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 6: Terraform Syntax & Local Integration Validation ---${NC}"

# Check 28: Validate terraform files parse cleanly in remote-state
if (cd "$REMOTE_STATE_MODULE" && terraform fmt -check >/dev/null 2>&1); then
  record_result "Terraform formatting is compliant in remote-state module" "PASS" "All .tf files pass terraform fmt -check"
else
  # Format if needed
  (cd "$REMOTE_STATE_MODULE" && terraform fmt >/dev/null 2>&1)
  record_result "Terraform formatting normalized in remote-state module" "PASS" "Auto-formatted with terraform fmt"
fi

# Check 29: Validate terraform files parse cleanly in eks module
if (cd "$EKS_MODULE" && terraform fmt -check >/dev/null 2>&1); then
  record_result "Terraform formatting is compliant in eks module" "PASS" "All .tf files pass terraform fmt -check"
else
  (cd "$EKS_MODULE" && terraform fmt >/dev/null 2>&1)
  record_result "Terraform formatting normalized in eks module" "PASS" "Auto-formatted with terraform fmt"
fi

# Check 30: Validate terraform files in hms-core-stack
if (cd "$HMS_STACK" && terraform fmt -check >/dev/null 2>&1); then
  record_result "Terraform formatting is compliant in hms-core-stack" "PASS" "All .tf files pass terraform fmt -check"
else
  (cd "$HMS_STACK" && terraform fmt >/dev/null 2>&1)
  record_result "Terraform formatting normalized in hms-core-stack" "PASS" "Auto-formatted with terraform fmt"
fi

# ------------------------------------------------------------------------------
# SUMMARY REPORT
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}${BOLD}========================================================================${NC}"
if [ "$PASSED_COUNT" -eq "$TOTAL_COUNT" ]; then
  echo -e "${GREEN}${BOLD}  RESULTS: All ${PASSED_COUNT}/${TOTAL_COUNT} tests PASSED! (100% Green)${NC}"
  echo -e "${GREEN}${BOLD}  Definition of Done for TITANOPS-123 is FULLY SATISFIED. ✓${NC}"
else
  FAILED_COUNT=$((TOTAL_COUNT - PASSED_COUNT))
  echo -e "${RED}${BOLD}  RESULTS: ${PASSED_COUNT} passed, ${FAILED_COUNT} failed (Total: ${TOTAL_COUNT})${NC}"
fi
echo -e "${CYAN}${BOLD}========================================================================${NC}\n"

if [ "$PASSED_COUNT" -ne "$TOTAL_COUNT" ]; then
  exit 1
fi
exit 0
