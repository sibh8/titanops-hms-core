#!/usr/bin/env bash
# ============================================================================
# Wrapper to run the TitanOps HMS Terraform stack for a specific environment.
#
# Usage:  ./hms.sh <environment> <action> [extra terraform args...]
#   environment : dev | local  (any folder under infra/environments)
#   action      : init|plan|apply|destroy|fmt|validate|output|console
#
# The DB password is read from TF_VAR_db_password (never passed on the CLI).
#
# Examples:
#   ./hms.sh local apply
#   ./hms.sh dev plan
#   ./hms.sh dev apply -auto-approve
# ============================================================================
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <environment> <action> [extra terraform args...]" >&2
  echo "  action: init|plan|apply|destroy|fmt|validate|output|console" >&2
  exit 1
fi

ENVIRONMENT="$1"
ACTION="$2"
shift 2
EXTRA=("$@")

# ---- Resolve paths relative to this script ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(dirname "$SCRIPT_DIR")"
STACK_DIR="$INFRA_ROOT/infra-stack/hms-core-stack"
ENV_DIR="$INFRA_ROOT/environments/$ENVIRONMENT"

# ---- Validation ----
command -v terraform >/dev/null 2>&1 || { echo "terraform not found on PATH. Install Terraform >= 1.5." >&2; exit 1; }
if [[ ! -f "$ENV_DIR/infra-config/config.yaml" ]]; then
  echo "Environment '$ENVIRONMENT' not found. Expected: $ENV_DIR/infra-config/config.yaml" >&2
  exit 1
fi

echo "==> Environment : $ENVIRONMENT"
echo "==> Action      : $ACTION"
echo "==> Stack       : $STACK_DIR"

CHDIR="-chdir=$STACK_DIR"
TFVAR=(-var "env=$ENVIRONMENT")

BACKEND_CONFIG=()
if [[ -f "$ENV_DIR/backend.hcl" ]]; then
  BACKEND_CONFIG=(-backend-config="$ENV_DIR/backend.hcl")
fi

# Auto-init if not initialized yet (for non-init actions).
if [[ "$ACTION" != "init" && ! -d "$STACK_DIR/.terraform" ]]; then
  echo "==> .terraform missing - running init first"
  terraform "$CHDIR" init "${BACKEND_CONFIG[@]}"
fi

case "$ACTION" in
  init)     terraform "$CHDIR" init "${BACKEND_CONFIG[@]}" "${EXTRA[@]}" ;;
  fmt)      terraform "$CHDIR" fmt -recursive "${EXTRA[@]}" ;;
  validate) terraform "$CHDIR" validate "${EXTRA[@]}" ;;
  output)   terraform "$CHDIR" output "${EXTRA[@]}" ;;
  console)  terraform "$CHDIR" console "${TFVAR[@]}" "${EXTRA[@]}" ;;
  plan)     terraform "$CHDIR" plan "${TFVAR[@]}" "${EXTRA[@]}" ;;
  apply)    terraform "$CHDIR" apply "${TFVAR[@]}" "${EXTRA[@]}" ;;
  destroy)  terraform "$CHDIR" destroy "${TFVAR[@]}" "${EXTRA[@]}" ;;
  *)
    echo "Unknown action: $ACTION" >&2
    echo "  action: init|plan|apply|destroy|fmt|validate|output|console" >&2
    exit 1
    ;;
esac
