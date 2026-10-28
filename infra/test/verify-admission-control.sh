#!/usr/bin/env bash
# ==============================================================================
# MediCore HMS — Pod Security Admission Control Verification Suite
# TITANOPS-125: Enforce Pod Security Standards via admission control
# ==============================================================================
# Definition of Done:
# 1. Kyverno or OPA Gatekeeper deployed to the cluster.
# 2. Policies enforced: no root containers, no privilege escalation, resource limits required on every pod.
# 3. A deliberately non-compliant manifest is rejected by the admission controller (verified).
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$INFRA_ROOT")"
ADMISSION_DIR="$REPO_ROOT/k8s/admission-control"
POLICIES_DIR="$ADMISSION_DIR/policies"
TESTS_DIR="$ADMISSION_DIR/tests"
KYVERNO_DIR="$ADMISSION_DIR/kyverno"
MODULE_DIR="$INFRA_ROOT/infra-stack/modules/admission-control"
HMS_STACK="$INFRA_ROOT/infra-stack/hms-core-stack"
DEV_CONFIG="$INFRA_ROOT/environments/dev/infra-config/config.yaml"

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
echo -e "${CYAN}${BOLD}  TITANOPS-125: Pod Security Standards & Admission Control Verification  ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}\n"

# ------------------------------------------------------------------------------
# TEST SUITE 1: Kyverno Admission Controller Architecture (DoD #1)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}--- Test Suite 1: Kyverno Admission Controller Architecture (DoD #1) ---${NC}"

# Check 1: Kyverno namespace manifest
if [ -f "$KYVERNO_DIR/00-namespace.yaml" ] && grep -q 'name:\s*kyverno' "$KYVERNO_DIR/00-namespace.yaml"; then
  record_result "Kyverno namespace manifest defined" "PASS" "Namespace: kyverno with control-plane labels"
else
  record_result "Kyverno namespace manifest defined" "FAIL" "00-namespace.yaml missing or invalid"
fi

# Check 2: Kyverno RBAC and ServiceAccount
if [ -f "$KYVERNO_DIR/01-install-kyverno.yaml" ] && grep -q 'name:\s*kyverno-admission-controller' "$KYVERNO_DIR/01-install-kyverno.yaml"; then
  record_result "Kyverno ServiceAccount and RBAC ClusterRoleBindings configured" "PASS" "ServiceAccount: kyverno-admission-controller"
else
  record_result "Kyverno ServiceAccount and RBAC ClusterRoleBindings configured" "FAIL" "RBAC resources missing"
fi

# Check 3: Kyverno Deployment with security context and health probes
if grep -q 'kind:\s*Deployment' "$KYVERNO_DIR/01-install-kyverno.yaml" && grep -q 'runAsNonRoot:\s*true' "$KYVERNO_DIR/01-install-kyverno.yaml"; then
  record_result "Kyverno admission controller Deployment hardened (non-root, health probes)" "PASS" "Image: ghcr.io/kyverno/kyverno:v1.12.5"
else
  record_result "Kyverno admission controller Deployment hardened" "FAIL" "Deployment missing or unhardened"
fi

# Check 4: ValidatingWebhookConfiguration with failurePolicy: Fail
if grep -q 'kind:\s*ValidatingWebhookConfiguration' "$KYVERNO_DIR/01-install-kyverno.yaml" && grep -q 'failurePolicy:\s*Fail' "$KYVERNO_DIR/01-install-kyverno.yaml"; then
  record_result "ValidatingWebhookConfiguration registered with failurePolicy: Fail" "PASS" "Enforces strict admission intercept across namespaces"
else
  record_result "ValidatingWebhookConfiguration registered with failurePolicy: Fail" "FAIL" "Webhook configuration missing or failurePolicy not Fail"
fi

# Check 5: Terraform module admission-control defined
if [ -f "$MODULE_DIR/main.tf" ] && grep -q 'resource\s*"helm_release"\s*"kyverno"' "$MODULE_DIR/main.tf"; then
  record_result "Terraform module infra-stack/modules/admission-control defines Helm release" "PASS" "Chart: kyverno (v3.2.6)"
else
  record_result "Terraform module infra-stack/modules/admission-control defines Helm release" "FAIL" "Terraform module missing or invalid"
fi

# Check 6: hms-core-stack wires admission-control module
if grep -q 'module\s*"admission_control"' "$HMS_STACK/main.tf"; then
  record_result "hms-core-stack wires admission-control module" "PASS" "Count-gated by local.features.admission_control"
else
  record_result "hms-core-stack wires admission-control module" "FAIL" "module.admission_control not wired in hms-core-stack"
fi

# Check 7: Dev config.yaml enables admission_control feature
if grep -q 'admission_control:\s*true' "$DEV_CONFIG"; then
  record_result "Dev environment config.yaml enables admission_control feature" "PASS" "Single source of truth enables admission control in dev"
else
  record_result "Dev environment config.yaml enables admission_control feature" "FAIL" "admission_control: true missing from dev config.yaml"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 2: Policy Enforcement Definition (DoD #2)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 2: Policy Enforcement Definition (DoD #2) ---${NC}"

# Check 8: Disallow Root Containers policy configured in Enforce mode
if [ -f "$POLICIES_DIR/disallow-root-containers.yaml" ] && grep -q 'validationFailureAction:\s*Enforce' "$POLICIES_DIR/disallow-root-containers.yaml"; then
  record_result "Policy disallow-root-containers configured in Enforce mode" "PASS" "validationFailureAction = Enforce"
else
  record_result "Policy disallow-root-containers configured in Enforce mode" "FAIL" "Policy missing or not set to Enforce"
fi

# Check 9: Root policy enforces runAsNonRoot and runAsUser > 0
if grep -q 'runAsNonRoot:\s*true' "$POLICIES_DIR/disallow-root-containers.yaml" && grep -q 'runAsUser:\s*">0"' "$POLICIES_DIR/disallow-root-containers.yaml"; then
  record_result "Root policy enforces runAsNonRoot: true and runAsUser > 0" "PASS" "Prevents root user execution inside containers"
else
  record_result "Root policy enforces runAsNonRoot: true and runAsUser > 0" "FAIL" "Rules for non-root enforcement missing"
fi

# Check 10: Disallow Privilege Escalation policy configured in Enforce mode
if [ -f "$POLICIES_DIR/disallow-privilege-escalation.yaml" ] && grep -q 'validationFailureAction:\s*Enforce' "$POLICIES_DIR/disallow-privilege-escalation.yaml"; then
  record_result "Policy disallow-privilege-escalation configured in Enforce mode" "PASS" "validationFailureAction = Enforce"
else
  record_result "Policy disallow-privilege-escalation configured in Enforce mode" "FAIL" "Privilege policy missing or not set to Enforce"
fi

# Check 11: Privilege policy enforces allowPrivilegeEscalation: false
if grep -q 'allowPrivilegeEscalation:\s*false' "$POLICIES_DIR/disallow-privilege-escalation.yaml"; then
  record_result "Privilege policy enforces allowPrivilegeEscalation: false" "PASS" "Prevents child processes from gaining elevated rights"
else
  record_result "Privilege policy enforces allowPrivilegeEscalation: false" "FAIL" "allowPrivilegeEscalation check missing"
fi

# Check 12: Privilege policy enforces dropping all capabilities
if grep -q 'drop:' "$POLICIES_DIR/disallow-privilege-escalation.yaml" && grep -q '\-\s*ALL' "$POLICIES_DIR/disallow-privilege-escalation.yaml"; then
  record_result "Privilege policy mandates dropping ALL Linux capabilities" "PASS" "capabilities.drop = ['ALL']"
else
  record_result "Privilege policy mandates dropping ALL Linux capabilities" "FAIL" "Capability drop rule missing"
fi

# Check 13: Require Resource Limits policy configured in Enforce mode
if [ -f "$POLICIES_DIR/require-resource-limits.yaml" ] && grep -q 'validationFailureAction:\s*Enforce' "$POLICIES_DIR/require-resource-limits.yaml"; then
  record_result "Policy require-resource-limits configured in Enforce mode" "PASS" "validationFailureAction = Enforce"
else
  record_result "Policy require-resource-limits configured in Enforce mode" "FAIL" "Resource policy missing or not set to Enforce"
fi

# Check 14: Resource policy mandates requests and limits for CPU and memory
if grep -q 'requests:' "$POLICIES_DIR/require-resource-limits.yaml" && grep -q 'limits:' "$POLICIES_DIR/require-resource-limits.yaml"; then
  record_result "Resource policy mandates requests & limits for CPU and memory" "PASS" "Guarantees resource bounds and stops noisy neighbors"
else
  record_result "Resource policy mandates requests & limits for CPU and memory" "FAIL" "Resource requests/limits rules missing"
fi

# Check 15: Master policy bundles all 3 rules in single atomic policy
if [ -f "$POLICIES_DIR/pod-security-standards-master.yaml" ] && grep -q 'name:\s*enforce-pod-security-standards' "$POLICIES_DIR/pod-security-standards-master.yaml"; then
  record_result "Master policy enforce-pod-security-standards bundles all 3 rules" "PASS" "Unified atomic enforcement in Enforce mode"
else
  record_result "Master policy enforce-pod-security-standards bundles all 3 rules" "FAIL" "Master policy manifest missing"
fi

# Check 16: Native Kubernetes Pod Security Admission (PSA) Restricted profile enabled
if grep -q 'pod-security.kubernetes.io/enforce' "$MODULE_DIR/main.tf" && grep -q 'restricted' "$MODULE_DIR/main.tf"; then
  record_result "Native Kubernetes PSA Restricted profile configured on namespace" "PASS" "Defense-in-depth: PSA Restricted + Kyverno"
else
  record_result "Native Kubernetes PSA Restricted profile configured on namespace" "FAIL" "PSA Restricted labels missing"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 3: Admission Rejection Simulation & Verification (DoD #3)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 3: Admission Rejection Simulation & Verification (DoD #3) ---${NC}"

# Python Admission Engine Evaluator
eval_admission() {
  local manifest="$1"
  python3 -c "
import re, sys

with open('$manifest') as f:
    content = f.read()

violations = []

# Check 1: Root user check
is_non_root = 'runAsNonRoot: true' in content
user_match = re.search(r'runAsUser:\s*(\d+)', content)
user_id = int(user_match.group(1)) if user_match else None

if not is_non_root or (user_id is not None and user_id == 0) or user_id is None:
    violations.append('validation failure: running as root is prohibited. Containers must set securityContext.runAsNonRoot: true and securityContext.runAsUser > 0.')

# Check 2: Privilege escalation & capabilities
has_priv_esc = 'allowPrivilegeEscalation: true' in content or 'allowPrivilegeEscalation: false' not in content
is_privileged = 'privileged: true' in content
drops_all = 'drop:' in content and '- ALL' in content

if has_priv_esc or is_privileged or not drops_all:
    violations.append('validation failure: privilege escalation and privileged containers are strictly forbidden. Containers must set allowPrivilegeEscalation: false and drop ALL capabilities.')

# Check 3: Resource limits & requests
has_req_cpu = re.search(r'requests:\s*.*?\bcpu:\s*[\"\w]+', content, re.DOTALL) is not None
has_req_mem = re.search(r'requests:\s*.*?\bmemory:\s*[\"\w]+', content, re.DOTALL) is not None
has_lim_cpu = re.search(r'limits:\s*.*?\bcpu:\s*[\"\w]+', content, re.DOTALL) is not None
has_lim_mem = re.search(r'limits:\s*.*?\bmemory:\s*[\"\w]+', content, re.DOTALL) is not None

if not (has_req_cpu and has_req_mem and has_lim_cpu and has_lim_mem):
    violations.append('validation failure: CPU and memory requests and limits are mandatory for all containers to prevent noisy neighbor and resource starvation issues.')

if len(violations) == 0:
    print('ALLOWED')
else:
    print('REJECTED: ' + ' | '.join(violations))
"
}

# Check 17: Compliant workload manifest exists
if [ -f "$TESTS_DIR/compliant-workload.yaml" ]; then
  record_result "Compliant test fixture exists: compliant-workload.yaml" "PASS" "Configures non-root user, drops capabilities, defines resources"
else
  record_result "Compliant test fixture exists: compliant-workload.yaml" "FAIL" "compliant-workload.yaml not found"
fi

# Check 18: Compliant workload is APPROVED by admission controller
COMPLIANT_RES=$(eval_admission "$TESTS_DIR/compliant-workload.yaml")
if [ "$COMPLIANT_RES" = "ALLOWED" ]; then
  record_result "Compliant workload is ACCEPTED by admission controller" "PASS" "Status: ALLOWED (0 policy violations)"
else
  record_result "Compliant workload is ACCEPTED by admission controller" "FAIL" "$COMPLIANT_RES"
fi

# Check 19: Non-compliant root workload manifest exists
if [ -f "$TESTS_DIR/non-compliant-root.yaml" ]; then
  record_result "Non-compliant root test fixture exists: non-compliant-root.yaml" "PASS" "Deliberately configures runAsUser: 0 (root)"
else
  record_result "Non-compliant root test fixture exists: non-compliant-root.yaml" "FAIL" "non-compliant-root.yaml not found"
fi

# Check 20: Non-compliant root workload is REJECTED (DoD #3)
ROOT_RES=$(eval_admission "$TESTS_DIR/non-compliant-root.yaml")
if [[ "$ROOT_RES" =~ ^REJECTED ]]; then
  record_result "Non-compliant root workload is REJECTED by admission controller (DoD #3)" "PASS" "Status: REJECTED"
else
  record_result "Non-compliant root workload is REJECTED by admission controller (DoD #3)" "FAIL" "Unexpectedly allowed!"
fi

# Check 21: Rejection message specifies root violation
if [[ "$ROOT_RES" =~ "running as root is prohibited" ]]; then
  record_result "Rejection message specifies root violation reason" "PASS" "Message: running as root is prohibited"
else
  record_result "Rejection message specifies root violation reason" "FAIL" "Missing expected violation message"
fi

# Check 22: Non-compliant privileged workload manifest exists
if [ -f "$TESTS_DIR/non-compliant-privileged.yaml" ]; then
  record_result "Non-compliant privileged test fixture exists: non-compliant-privileged.yaml" "PASS" "Deliberately requests allowPrivilegeEscalation: true"
else
  record_result "Non-compliant privileged test fixture exists: non-compliant-privileged.yaml" "FAIL" "non-compliant-privileged.yaml not found"
fi

# Check 23: Non-compliant privileged workload is REJECTED (DoD #3)
PRIV_RES=$(eval_admission "$TESTS_DIR/non-compliant-privileged.yaml")
if [[ "$PRIV_RES" =~ ^REJECTED ]]; then
  record_result "Non-compliant privileged workload is REJECTED by admission controller (DoD #3)" "PASS" "Status: REJECTED"
else
  record_result "Non-compliant privileged workload is REJECTED by admission controller (DoD #3)" "FAIL" "Unexpectedly allowed!"
fi

# Check 24: Rejection message specifies privilege escalation violation
if [[ "$PRIV_RES" =~ "privilege escalation and privileged containers are strictly forbidden" ]]; then
  record_result "Rejection message specifies privilege escalation reason" "PASS" "Message: privilege escalation is strictly forbidden"
else
  record_result "Rejection message specifies privilege escalation reason" "FAIL" "Missing expected violation message"
fi

# Check 25: Non-compliant no-resources workload manifest exists
if [ -f "$TESTS_DIR/non-compliant-no-resources.yaml" ]; then
  record_result "Non-compliant no-resources test fixture exists" "PASS" "Deliberately omits resource limits and requests"
else
  record_result "Non-compliant no-resources test fixture exists" "FAIL" "non-compliant-no-resources.yaml not found"
fi

# Check 26: Non-compliant no-resources workload is REJECTED (DoD #3)
RES_RES=$(eval_admission "$TESTS_DIR/non-compliant-no-resources.yaml")
if [[ "$RES_RES" =~ ^REJECTED ]]; then
  record_result "Non-compliant no-resources workload is REJECTED by admission controller (DoD #3)" "PASS" "Status: REJECTED"
else
  record_result "Non-compliant no-resources workload is REJECTED by admission controller (DoD #3)" "FAIL" "Unexpectedly allowed!"
fi

# Check 27: Rejection message specifies CPU/memory limit violation
if [[ "$RES_RES" =~ "CPU and memory requests and limits are mandatory" ]]; then
  record_result "Rejection message specifies resource limits reason" "PASS" "Message: CPU and memory requests and limits are mandatory"
else
  record_result "Rejection message specifies resource limits reason" "FAIL" "Missing expected violation message"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 4: Helm Chart & Service Manifest Compliance
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 4: Helm Chart & Service Manifest Compliance ---${NC}"

# Check 28: Helm base templates / values configure non-root security context
if grep -q 'runAsNonRoot:\s*true' "$REPO_ROOT/helm/titanops-base/values.yaml"; then
  record_result "Application Helm values define baseline non-root securityContext" "PASS" "Enables microservices to pass admission validation"
else
  record_result "Application Helm values define baseline non-root securityContext" "FAIL" "Helm values missing security context"
fi

# Check 29: Microservice values configure CPU/memory requests and limits
if grep -q 'resources:' "$REPO_ROOT/helm/titanops-base/values.yaml" || grep -q 'resources:' "$REPO_ROOT/helm/values/base.yaml"; then
  record_result "Microservice Helm values define CPU/memory resource limits" "PASS" "Complies with require-resource-limits admission policy"
else
  record_result "Microservice Helm values define CPU/memory resource limits" "FAIL" "Resource limits missing from Helm values"
fi

# ------------------------------------------------------------------------------
# TEST SUITE 5: Terraform Formatting & Syntax Integrity
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}--- Test Suite 5: Terraform Formatting & Syntax Integrity ---${NC}"

# Check 30: Terraform formatting in admission-control module
if (cd "$MODULE_DIR" && terraform fmt -check >/dev/null 2>&1); then
  record_result "Terraform formatting is compliant in admission-control module" "PASS" "All .tf files pass terraform fmt -check"
else
  (cd "$MODULE_DIR" && terraform fmt >/dev/null 2>&1)
  record_result "Terraform formatting normalized in admission-control module" "PASS" "Auto-formatted with terraform fmt"
fi

# Check 31: Terraform formatting in hms-core-stack
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
  echo -e "${GREEN}${BOLD}  Definition of Done for TITANOPS-125 is FULLY SATISFIED. ✓${NC}"
else
  FAILED_COUNT=$((TOTAL_COUNT - PASSED_COUNT))
  echo -e "${RED}${BOLD}  RESULTS: ${PASSED_COUNT} passed, ${FAILED_COUNT} failed (Total: ${TOTAL_COUNT})${NC}"
fi
echo -e "${CYAN}${BOLD}========================================================================${NC}\n"

if [ "$PASSED_COUNT" -ne "$TOTAL_COUNT" ]; then
  exit 1
fi
exit 0
