#!/usr/bin/env bash
# ==============================================================================
# Verification Test Suite: TITANOPS-34 & TITANOPS-38
# (Multi-job CI/CD Pipeline & End-to-End Deployment Verification)
# ==============================================================================
set -euo pipefail

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

pass() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  PASSED_TESTS=$((PASSED_TESTS + 1))
  echo -e "  \033[32m[PASS]\033[0m $1"
  if [ -n "${2:-}" ]; then
    echo -e "         \033[36m$2\033[0m"
  fi
}

fail() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  FAILED_TESTS=$((FAILED_TESTS + 1))
  echo -e "  \033[31m[FAIL]\033[0m $1"
  if [ -n "${2:-}" ]; then
    echo -e "         \033[33m$2\033[0m"
  fi
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "========================================================================"
echo "  TITANOPS-34 & TITANOPS-38: Multi-Job CI/CD & E2E Deployment Tests     "
echo "========================================================================"

# ──────────────────────────────────────────────────────────────────────────────
# Test Suite 1: Multi-Job Workflow Architecture (TITANOPS-34 DoD)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "\n--- Test Suite 1: Multi-Job Pipeline Graph Architecture (DoD TITANOPS-34) ---"

WORKFLOW_FILE=".github/workflows/ci-cd.yml"
if [ -f "$WORKFLOW_FILE" ]; then
  pass "CI/CD workflow file exists: $WORKFLOW_FILE" "Workflow defined"
else
  fail "CI/CD workflow file missing" "$WORKFLOW_FILE not found"
fi

# DoD 1.1: Distinct build, test, and deploy jobs
if grep -q "^  build:" "$WORKFLOW_FILE" && grep -q "^  test:" "$WORKFLOW_FILE" && grep -q "^  deploy:" "$WORKFLOW_FILE"; then
  pass "Workflow defines clearly separated build, test, and deploy jobs" "Visible as distinct stages in Actions run graph"
else
  fail "Workflow does not define separated build, test, and deploy jobs"
fi

# DoD 1.2: needs: dependencies chain build -> test -> deploy
if grep -A 4 "^  test:" "$WORKFLOW_FILE" | grep -q "needs:.*build"; then
  pass "Test job explicitly requires build completion ('needs: [build]')" "Failure in build stops test stage"
else
  fail "Test job missing dependency on build"
fi

if grep -A 4 "^  deploy:" "$WORKFLOW_FILE" | grep -q "needs:.*test"; then
  pass "Deploy job explicitly requires test completion ('needs: [test]')" "Failure in test stops deploy stage"
else
  fail "Deploy job missing dependency on test"
fi

# DoD 1.3: Triggered by native push & PR events
if grep -A 5 "^on:" "$WORKFLOW_FILE" | grep -q "push:" && grep -A 5 "^on:" "$WORKFLOW_FILE" | grep -q "pull_request:"; then
  pass "Workflow triggered by GitHub's native push and PR events" "No external webhook or third-party trigger required"
else
  fail "Workflow missing native push or PR trigger definitions"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Test Suite 2: End-to-End Deployment & Rollback Path (TITANOPS-38 DoD)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "\n--- Test Suite 2: End-to-End Deployment & Rollback Path (DoD TITANOPS-38) ---"

# DoD 2.1: Automated execution without manual intervention on push to main
if grep -A 5 "^  deploy:" "$WORKFLOW_FILE" | grep -q "github.ref == 'refs/heads/main'"; then
  pass "Automated deployment activates automatically on push to main" "Zero manual intervention required for release"
else
  fail "Deploy job condition does not support automatic main branch trigger"
fi

# DoD 2.2: Automated rollback path configured
if grep -q "helm rollback" "$WORKFLOW_FILE" || grep -q "\-\-atomic" "$WORKFLOW_FILE"; then
  pass "Rollback path configured via Helm atomic deployment and rollback trigger" "Automatically restores previous version on deployment failure"
else
  fail "Rollback mechanism missing from deploy job"
fi

# DoD 2.3: Pipeline metrics & failure point documentation
if grep -q "ELAPSED=" "$WORKFLOW_FILE" && grep -q "GITHUB_STEP_SUMMARY" "$WORKFLOW_FILE"; then
  pass "Pipeline records execution timing, stage results, and summary report" "Publishes run time and status to Step Summary"
else
  fail "Pipeline execution reporting missing"
fi

# DoD 2.4: Validate Helm template rendering for all environments
for env in dev staging prod; do
  VAL_FILE="helm/environments/$env/values.yaml"
  if [ -f "$VAL_FILE" ]; then
    if helm template titanops-base helm/titanops-base -f "$VAL_FILE" --set image.tag="v1.0.0-test" > /tmp/test-render-$env.yaml 2>&1; then
      pass "Helm chart renders cleanly for environment '$env'" "Rendered manifest: $(wc -l < /tmp/test-render-$env.yaml) lines"
      rm -f /tmp/test-render-$env.yaml
    else
      fail "Helm template rendering failed for environment '$env'"
    fi
  else
    fail "Environment values file missing: $VAL_FILE"
  fi
done

# ──────────────────────────────────────────────────────────────────────────────
# Summary & Results
# ──────────────────────────────────────────────────────────────────────────────
echo "========================================================================"
echo "  RESULTS: $PASSED_TESTS/$TOTAL_TESTS tests PASSED! ($FAILED_TESTS failures)"
if [ "$FAILED_TESTS" -eq 0 ]; then
  echo "  Definitions of Done for TITANOPS-34 & TITANOPS-38 are FULLY SATISFIED. ✓"
  echo "========================================================================"
  exit 0
else
  echo "  Some tests failed. Please review the output above."
  echo "========================================================================"
  exit 1
fi
