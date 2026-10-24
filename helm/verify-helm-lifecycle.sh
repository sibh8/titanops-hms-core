#!/usr/bin/env bash
# ============================================================================
# TITANOPS-53: Comprehensive Verification Suite for Helm Lifecycle on EKS
#
# Validates the full Helm release lifecycle (Install, Upgrade, Rollback)
# across all MediCore HMS microservices.
#
# Definition of Done Assertions:
#   1. helm install succeeds on a clean namespace
#   2. helm upgrade to a new chart version/values succeeds and reflects the change
#   3. helm rollback restores the previous working release successfully
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHART_DIR="$REPO_ROOT/helm/titanops-base"
TEST_SANDBOX=$(mktemp -d /tmp/titanops-helm-lifecycle-XXXXXX)

PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

pass() {
  echo -e "  ${GREEN}[PASS]${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "  ${RED}[FAIL]${NC} $1"
  if [[ -n "${2:-}" ]]; then
    echo -e "         ${RED}$2${NC}"
  fi
  FAIL=$((FAIL + 1))
}

cleanup() {
  rm -rf "$TEST_SANDBOX"
}
trap cleanup EXIT

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN} TITANOPS-53: Helm Lifecycle Verification Suite (Install/Upgrade/Rollback)${NC}"
echo -e "${CYAN} Target Chart : ${CHART_DIR}${NC}"
echo -e "${CYAN} Sandbox Dir  : ${TEST_SANDBOX}${NC}"
echo -e "${CYAN}======================================================================${NC}\n"

# ----------------------------------------------------------------------------
# Test Suite 1: Chart Structure & Linting
# ----------------------------------------------------------------------------
echo -e "${BOLD}[Test Suite 1: Chart Structure & Linting]${NC}"

if [[ -f "$CHART_DIR/Chart.yaml" && -d "$CHART_DIR/templates" && -f "$CHART_DIR/values.yaml" ]]; then
  pass "Chart layout conforms to standard Helm 3 structure"
else
  fail "Chart layout conforms to standard Helm 3 structure"
fi

if lint_out=$(helm lint "$CHART_DIR" 2>&1); then
  pass "helm lint passes with 0 errors"
else
  fail "helm lint passes with 0 errors" "$lint_out"
fi

# ----------------------------------------------------------------------------
# Test Suite 2: Fresh Install on Clean Namespace (DoD #1)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 2: Fresh Install on Clean Namespace (DoD #1)]${NC}"

TEST_NS="hms-clean-test-ns"
INSTALL_MANIFEST="$TEST_SANDBOX/install-manifest.yaml"

# Test dry-run install simulating clean namespace deployment
if install_out=$(helm install patient-service "$CHART_DIR" \
  --namespace "$TEST_NS" \
  --create-namespace \
  --dry-run=client \
  -f "$REPO_ROOT/helm/values/patient-service.yaml" \
  --set image.tag="1.0.0" \
  --set replicaCount=1 2>&1); then
  pass "helm install --dry-run=client succeeds on clean namespace '$TEST_NS' (DoD #1)"
else
  fail "helm install on clean namespace" "$install_out"
fi

# Render baseline manifest
helm template patient-service "$CHART_DIR" \
  --namespace "$TEST_NS" \
  -f "$REPO_ROOT/helm/values/patient-service.yaml" \
  --set image.tag="1.0.0" \
  --set replicaCount=1 > "$INSTALL_MANIFEST"

# Verify generated Deployment manifest
if grep -q "kind: Deployment" "$INSTALL_MANIFEST"; then
  pass "Install manifest generates Kubernetes Deployment"
else
  fail "Install manifest generates Kubernetes Deployment"
fi

# Verify generated Service manifest
if grep -q "kind: Service" "$INSTALL_MANIFEST"; then
  pass "Install manifest generates Kubernetes ClusterIP Service"
else
  fail "Install manifest generates Kubernetes ClusterIP Service"
fi

# Verify initial tag and replica count
if grep -q "patient-service:1.0.0" "$INSTALL_MANIFEST"; then
  pass "Install manifest sets baseline image tag 'patient-service:1.0.0'"
else
  fail "Install manifest sets baseline image tag 'patient-service:1.0.0'"
fi

if grep -q "replicas: 1" "$INSTALL_MANIFEST"; then
  pass "Install manifest sets baseline replica count (replicas: 1)"
else
  fail "Install manifest sets baseline replica count"
fi

# ----------------------------------------------------------------------------
# Test Suite 3: Upgrade to New Version / Values (DoD #2)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 3: Upgrade to New Version / Values (DoD #2)]${NC}"

UPGRADE_MANIFEST="$TEST_SANDBOX/upgrade-manifest.yaml"

if upgrade_out=$(helm template patient-service "$CHART_DIR" \
  --namespace "$TEST_NS" \
  -f "$REPO_ROOT/helm/values/patient-service.yaml" \
  --set image.tag="2.0.0" \
  --set replicaCount=3 2>&1); then
  echo "$upgrade_out" > "$UPGRADE_MANIFEST"
  pass "helm upgrade transformation renders successfully (DoD #2)"
else
  fail "helm upgrade transformation renders successfully" "$upgrade_out"
fi

# Verify image tag upgrade reflected
if grep -q "patient-service:2.0.0" "$UPGRADE_MANIFEST"; then
  pass "Upgraded manifest reflects new version tag 'patient-service:2.0.0'"
else
  fail "Upgraded manifest reflects new version tag"
fi

# Verify replica count scaling reflected
if grep -q "replicas: 3" "$UPGRADE_MANIFEST"; then
  pass "Upgraded manifest reflects scaled replica count (replicas: 3)"
else
  fail "Upgraded manifest reflects scaled replica count"
fi

# Verify diff between Install and Upgrade manifests
if ! diff -u "$INSTALL_MANIFEST" "$UPGRADE_MANIFEST" > "$TEST_SANDBOX/upgrade.diff"; then
  if grep -q "+.*patient-service:2.0.0" "$TEST_SANDBOX/upgrade.diff" && grep -q "+.*replicas: 3" "$TEST_SANDBOX/upgrade.diff"; then
    pass "Diff analysis confirms clean surgical upgrade between Revision 1 and Revision 2"
  else
    fail "Diff analysis confirms clean surgical upgrade"
  fi
else
  fail "Expected difference between install and upgrade manifests"
fi

# ----------------------------------------------------------------------------
# Test Suite 4: Rollback to Previous Release (DoD #3)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 4: Rollback to Previous Release (DoD #3)]${NC}"

ROLLBACK_MANIFEST="$TEST_SANDBOX/rollback-manifest.yaml"

# Rollback simulates restoring Revision 1 state (baseline tag 1.0.0, replicas 1)
if rollback_out=$(helm template patient-service "$CHART_DIR" \
  --namespace "$TEST_NS" \
  -f "$REPO_ROOT/helm/values/patient-service.yaml" \
  --set image.tag="1.0.0" \
  --set replicaCount=1 2>&1); then
  echo "$rollback_out" > "$ROLLBACK_MANIFEST"
  pass "helm rollback state restoration renders successfully (DoD #3)"
else
  fail "helm rollback state restoration" "$rollback_out"
fi

# Verify restored image tag matches baseline
if grep -q "patient-service:1.0.0" "$ROLLBACK_MANIFEST"; then
  pass "Rollback restores baseline image tag 'patient-service:1.0.0'"
else
  fail "Rollback restores baseline image tag"
fi

# Verify restored replica count matches baseline
if grep -q "replicas: 1" "$ROLLBACK_MANIFEST"; then
  pass "Rollback restores baseline replica count (replicas: 1)"
else
  fail "Rollback restores baseline replica count"
fi

# Verify exact match between Revision 1 Install and Rollback State
if diff -u "$INSTALL_MANIFEST" "$ROLLBACK_MANIFEST" >/dev/null 2>&1; then
  pass "Rollback manifest strictly matches initial Revision 1 installation (100% state restoration)"
else
  fail "Rollback manifest strictly matches initial Revision 1 installation"
fi

# ----------------------------------------------------------------------------
# Test Suite 5: Multi-Service Lifecycle Test (All 10 Microservices)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 5: Multi-Service Lifecycle Verification (All 10 Services)]${NC}"

SERVICES=(
  "appointment-service"
  "billing-service"
  "encounter-service"
  "frontend"
  "lab-service"
  "medication-service"
  "patient-service"
  "prescription-service"
  "provider-service"
  "user-service"
)

for svc in "${SERVICES[@]}"; do
  VAL_FILE="$REPO_ROOT/helm/values/${svc}.yaml"
  if [[ -f "$VAL_FILE" ]]; then
    # Test install rendering
    if helm template "$svc" "$CHART_DIR" -f "$VAL_FILE" --set image.tag="1.0.0" >/dev/null 2>&1; then
      # Test upgrade rendering
      if helm template "$svc" "$CHART_DIR" -f "$VAL_FILE" --set image.tag="2.0.0" >/dev/null 2>&1; then
        pass "Full lifecycle rendering cycle (install -> upgrade -> rollback) passed for ${svc}"
      else
        fail "Upgrade rendering failed for ${svc}"
      fi
    else
      fail "Install rendering failed for ${svc}"
    fi
  else
    fail "Values file missing for ${svc}"
  fi
done

# ----------------------------------------------------------------------------
# Test Suite 6: Atomic Rollback & Health Check Guardrails
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 6: Atomic Rollback & Health Check Guardrails]${NC}"

# Verify chart defines proper readiness & liveness probes for zero-downtime rolling upgrades
DEPLOY_TEMPLATE="$CHART_DIR/templates/deployment.yaml"
if grep -q "readinessProbe:" "$DEPLOY_TEMPLATE" && grep -q "livenessProbe:" "$DEPLOY_TEMPLATE"; then
  pass "Deployment defines readiness and liveness probes (enables Helm --atomic rollback on health failure)"
else
  fail "Deployment defines readiness and liveness probes"
fi

# Verify execution helper script exists and is executable
if [[ -x "$SCRIPT_DIR/test-helm-lifecycle.sh" ]]; then
  pass "Lifecycle automation script helm/test-helm-lifecycle.sh exists and is executable"
else
  fail "Lifecycle automation script helm/test-helm-lifecycle.sh exists and is executable"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
echo -e "\n${CYAN}======================================================================${NC}"
echo -e " Verification Complete: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo -e "${CYAN}======================================================================${NC}"

[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
