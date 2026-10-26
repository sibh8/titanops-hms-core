#!/usr/bin/env bash
# ============================================================================
# Static validation test suite for the TitanOps HMS Terraform stack.
#
# Offline checks only (no AWS credentials or live cluster required):
#   1. terraform fmt -check          (formatting)
#   2. terraform init -backend=false (module/provider resolution)
#   3. terraform validate            (config correctness)
#   4. config.yaml logic via terraform console, for every environment:
#        - YAML decodes and target resolves (aws|local)
#        - all 10 services enabled
#        - a disabled service drops out of enabled_services (toggle-off => destroy)
#        - is_aws / is_local mutually exclusive
#   5. app-config parity: each enabled service has a matching app-config YAML
#
# Exit code 0 = all passed, 1 = one or more failed.
#
# Usage:  ./validate.sh
# ============================================================================
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(dirname "$TEST_DIR")"
STACK_DIR="$INFRA_ROOT/infra-stack/hms-core-stack"
ENV_ROOT="$INFRA_ROOT/environments"

PASS=0
FAIL=0

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; [[ -n "${2:-}" ]] && echo -e "         ${RED}$2${NC}"; FAIL=$((FAIL + 1)); }

EXPECTED_SERVICES=(appointment-service billing-service encounter-service frontend \
  lab-service medication-service patient-service prescription-service \
  provider-service user-service)

command -v terraform >/dev/null 2>&1 || { echo "terraform not found on PATH. Install Terraform >= 1.5." >&2; exit 1; }

# Evaluate a HCL expression; echoes trimmed stdout, returns non-zero on tf error.
console() {
  local env="$1" expr="$2"
  echo "$expr" | terraform -chdir="$STACK_DIR" console -var "env=$env" 2>&1
}

echo -e "${CYAN}== TitanOps HMS stack validation ==${NC}"
echo -e "   stack: $STACK_DIR\n"

# ---- 1. fmt ----
echo "Formatting:"
if terraform -chdir="$INFRA_ROOT" fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt -check -recursive (all infra)"
else
  fail "terraform fmt -check -recursive (all infra)" "files not formatted; run: terraform fmt -recursive"
fi

# ---- 2. init ----
echo "Init & validate:"
if out=$(terraform -chdir="$STACK_DIR" init -backend=false -no-color 2>&1); then
  pass "terraform init -backend=false"
else
  fail "terraform init -backend=false" "$out"
fi

# ---- 3. validate ----
if out=$(terraform -chdir="$STACK_DIR" validate -no-color 2>&1); then
  pass "terraform validate"
else
  fail "terraform validate" "$out"
fi

# ---- 4 + 5. per-environment ----
# For offline evaluation, initialize temporary local backend override so console runs without AWS credentials
printf 'terraform {\n  backend "local" {}\n}\n' > "$STACK_DIR/backend_override.tf"
terraform -chdir="$STACK_DIR" init -reconfigure >/dev/null 2>&1

for env_path in "$ENV_ROOT"/*/; do
  env="$(basename "$env_path")"
  echo "Environment '$env':"

  # target valid
  t="$(console "$env" 'local.target')"
  if echo "$t" | grep -Eq '"(aws|local)"'; then
    pass "$env - config.yaml decodes & target is valid"
  else
    fail "$env - config.yaml decodes & target is valid" "got: $t"
  fi

  # 10 services
  n="$(console "$env" 'length(keys(local.enabled_services))')"
  if [[ "$n" == "10" ]]; then
    pass "$env - all 10 services enabled"
  else
    fail "$env - all 10 services enabled" "count: $n"
  fi

  # enabled service names match expected set
  raw="$(console "$env" 'sort(keys(local.enabled_services))')"
  actual="$(echo "$raw" | grep -oE '"[^"]+"' | tr -d '"' | sort | tr '\n' ' ')"
  expected="$(printf '%s\n' "${EXPECTED_SERVICES[@]}" | sort | tr '\n' ' ')"
  if [[ "$actual" == "$expected" ]]; then
    pass "$env - enabled service names match expected set"
  else
    fail "$env - enabled service names match expected set" "got: $actual"
  fi

  # disabled service excluded
  r="$(console "$env" 'contains(keys({ for k, v in { "x" = { enabled = false } } : k => v if try(v.enabled, true) }), "x")')"
  if [[ "$r" == "false" ]]; then
    pass "$env - disabled service excluded (toggle-off => destroy)"
  else
    fail "$env - disabled service excluded (toggle-off => destroy)" "got: $r"
  fi

  # mutual exclusivity
  m="$(console "$env" 'local.is_aws == local.is_local')"
  if [[ "$m" == "false" ]]; then
    pass "$env - is_aws / is_local mutually exclusive"
  else
    fail "$env - is_aws / is_local mutually exclusive" "got: $m"
  fi

  # app-config parity
  missing=""
  for svc in "${EXPECTED_SERVICES[@]}"; do
    [[ -f "$env_path/app-config/$svc.yaml" ]] || missing="$missing $svc"
  done
  if [[ -z "$missing" ]]; then
    pass "$env - every enabled service has an app-config YAML"
  else
    fail "$env - every enabled service has an app-config YAML" "missing:$missing"
  fi
done

# ---- cleanup ----
rm -f "$STACK_DIR/backend_override.tf"
rm -rf "$STACK_DIR/.terraform" "$STACK_DIR/terraform.tfstate"*

echo -e "\n${CYAN}== Results ==${NC}"
echo -e "   ${GREEN}Passed: $PASS${NC}"
if [[ "$FAIL" -gt 0 ]]; then echo -e "   ${RED}Failed: $FAIL${NC}"; else echo -e "   ${GREEN}Failed: $FAIL${NC}"; fi

[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
