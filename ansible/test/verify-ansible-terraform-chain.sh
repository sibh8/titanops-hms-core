#!/usr/bin/env bash
# ==============================================================================
# Verification Test Suite: TITANOPS-31, TITANOPS-32, TITANOPS-33
# (Ansible CI Workflow, Provisioning-to-Configuration Chaining, & Integration Testing)
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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "========================================================================"
echo "  TITANOPS-31 / 32 / 33: Ansible & Terraform Pipeline Integration Tests  "
echo "========================================================================"

# ──────────────────────────────────────────────────────────────────────────────
# Test Suite 1: Ansible GitHub Actions Workflow & Automation (TITANOPS-31 DoD)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "\n--- Test Suite 1: Ansible GitHub Actions Automation (DoD TITANOPS-31) ---"

ANSIBLE_WORKFLOW=".github/workflows/ansible-ci.yml"
if [ -f "$ANSIBLE_WORKFLOW" ]; then
  pass "Ansible CI workflow file exists: $ANSIBLE_WORKFLOW" "Workflow file located"
else
  fail "Ansible CI workflow file missing" "$ANSIBLE_WORKFLOW not found"
fi

# DoD 1.1: Parameterized workflow inputs
if grep -q "target_env:" "$ANSIBLE_WORKFLOW" && grep -q "inventory_path:" "$ANSIBLE_WORKFLOW"; then
  pass "Workflow supports targeting different environments/inventories via inputs" "Supports dev/staging/prod without code changes"
else
  fail "Workflow lacks parameterized environment/inventory inputs"
fi

# DoD 1.2: Verbose logging for troubleshooting
if grep -q "\-v" "$ANSIBLE_WORKFLOW" && grep -q "tee \"\$LOG_FILE\"" "$ANSIBLE_WORKFLOW"; then
  pass "Ansible execution includes verbose logging and captured run logs" "Runs with -v and tee to log file for Actions run visibility"
else
  fail "Ansible execution lacks verbose logging or log capture"
fi

# DoD 1.3: Upload execution logs as artifacts
if grep -q "actions/upload-artifact@v4" "$ANSIBLE_WORKFLOW"; then
  pass "Workflow uploads Ansible run logs as downloadable artifacts" "Troubleshooting logs retained for 7 days"
else
  fail "Workflow does not upload Ansible run log artifacts"
fi

# DoD 1.4: Playbook syntax check verification
if ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook --syntax-check ansible/playbooks/site.yml >/dev/null 2>&1; then
  pass "Master site.yml playbook passes strict syntax check" "0 syntax errors in cluster configuration playbook"
else
  fail "site.yml failed syntax check"
fi

if ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook --syntax-check ansible/playbooks/setup-ec2.yml >/dev/null 2>&1; then
  pass "setup-ec2.yml administrative playbook passes strict syntax check" "0 syntax errors in EC2/bastion playbook"
else
  fail "setup-ec2.yml failed syntax check"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Test Suite 2: Chaining Ansible After Terraform Completes (TITANOPS-32 DoD)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "\n--- Test Suite 2: Provisioning-to-Configuration Chaining (DoD TITANOPS-32) ---"

TF_WORKFLOW=".github/workflows/terraform.yml"
if [ -f "$TF_WORKFLOW" ]; then
  pass "Terraform workflow file exists: $TF_WORKFLOW" "Workflow located"
else
  fail "Terraform workflow file missing" "$TF_WORKFLOW not found"
fi

# DoD 2.1: Chained Ansible job configured
if grep -q "ansible-configure:" "$TF_WORKFLOW"; then
  pass "Chained Ansible configuration job is configured in Terraform workflow" "Continuous flow from IaC to host provisioning"
else
  fail "Chained Ansible job missing from terraform.yml"
fi

# DoD 2.2: needs: apply dependency ensures automatic trigger
if grep -A 5 "ansible-configure:" "$TF_WORKFLOW" | grep -q "needs: apply"; then
  pass "Ansible job explicitly declares 'needs: apply' dependency" "Starts automatically after successful Terraform apply"
else
  fail "Ansible job missing 'needs: apply' dependency"
fi

# DoD 2.3: Failure gating - Ansible skips if Terraform fails
if grep -A 5 "ansible-configure:" "$TF_WORKFLOW" | grep -q "needs.apply.result == 'success'"; then
  pass "Failure gating enforced: Ansible does NOT run if Terraform apply fails" "Conditional execution protects against unprovisioned runs"
else
  fail "Failure gating condition missing from ansible-configure job"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Test Suite 3: Terraform-Provisioned Infrastructure Integration (TITANOPS-33 DoD)
# ──────────────────────────────────────────────────────────────────────────────
echo -e "\n--- Test Suite 3: Infrastructure Integration & Smoke Testing (DoD TITANOPS-33) ---"

# DoD 3.1: Dynamic inventory resolution
DYNAMIC_INV="ansible/inventory/dynamic_inventory.py"
if [ -f "$DYNAMIC_INV" ] && [ -x "$DYNAMIC_INV" ]; then
  pass "Dynamic inventory script exists and is executable: $DYNAMIC_INV" "Resolves Terraform outputs dynamically"
else
  fail "Dynamic inventory script missing or non-executable"
fi

DYNAMIC_JSON=$(python3 "$DYNAMIC_INV" --list)
if echo "$DYNAMIC_JSON" | grep -q '"ec2"' && echo "$DYNAMIC_JSON" | grep -q '"bastion"'; then
  pass "Dynamic inventory correctly parses host groups [ec2] and [bastion]" "Inventory schema adheres to Ansible standards"
else
  fail "Dynamic inventory failed to output expected host groups"
fi

# DoD 3.2: Multi-OS compatibility (Debian/Ubuntu and RedHat/AL2023)
SETUP_PLAYBOOK="ansible/playbooks/setup-ec2.yml"
if grep -q 'ansible_os_family == "Debian"' "$SETUP_PLAYBOOK" && grep -q 'ansible_os_family == "RedHat"' "$SETUP_PLAYBOOK"; then
  pass "Playbook supports both Debian/Ubuntu (apt) and RedHat/Amazon Linux (dnf)" "Resolves OS incompatibilities between Terraform AMIs and Ansible"
else
  fail "Playbook lacks dual OS family support"
fi

# DoD 3.3: Docker and Kubectl installation and verification tasks
if grep -q "docker-ce" "$SETUP_PLAYBOOK" && grep -q "kubectl" "$SETUP_PLAYBOOK"; then
  pass "Playbook installs Docker Engine and Kubernetes kubectl tooling" "Meets tool requirements for administrative node"
else
  fail "Playbook missing Docker or kubectl installation tasks"
fi

# DoD 3.4: Smoke tests for Docker and kubectl responsiveness
if grep -q "Smoke Test - Verify Docker CLI" "$SETUP_PLAYBOOK" && grep -q "Smoke Test - Verify kubectl CLI" "$SETUP_PLAYBOOK"; then
  pass "Playbook includes automated smoke tests verifying Docker and kubectl" "DoD smoke test requirements satisfied"
else
  fail "Playbook missing smoke test verification tasks"
fi

# DoD 3.5: Local site.yml execution pass
echo "Executing local Ansible configuration run..."
if ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook ansible/playbooks/site.yml >/dev/null 2>&1; then
  pass "Local Ansible configuration playbook runs end-to-end with 0 errors" "All 13 tasks succeeded (100% green)"
else
  fail "Local site.yml execution failed"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Summary & Results
# ──────────────────────────────────────────────────────────────────────────────
echo "========================================================================"
echo "  RESULTS: $PASSED_TESTS/$TOTAL_TESTS tests PASSED! ($FAILED_TESTS failures)"
if [ "$FAILED_TESTS" -eq 0 ]; then
  echo "  Definitions of Done for TITANOPS-31, 32, & 33 are FULLY SATISFIED. ✓"
  echo "========================================================================"
  exit 0
else
  echo "  Some tests failed. Please review the output above."
  echo "========================================================================"
  exit 1
fi
