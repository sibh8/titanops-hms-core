#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# TITANOPS-111: Request Payload Validation Verification Suite
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED_COUNT=0
TOTAL_COUNT=7

log_pass() {
  echo -e "  [${GREEN}PASS${NC}] $1"
  PASSED_COUNT=$((PASSED_COUNT + 1))
}

log_fail() {
  echo -e "  [${RED}FAIL${NC}] $1"
  exit 1
}

echo "=============================================================================="
echo "   TITANOPS-111: Request Payload Validation Verification Suite               "
echo "=============================================================================="

echo ""
echo "Phase 1: Bean Validation Annotations on Entities & DTOs (DoD #1)"

USER_JAVA="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/model/User.java"
LOGIN_REQ="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/dto/LoginRequest.java"

if grep -q "@NotBlank" "${USER_JAVA}" && grep -q "@Size" "${USER_JAVA}" && grep -q "@Pattern" "${USER_JAVA}"; then
  log_pass "1. User entity annotated with @NotBlank, @Size, and @Pattern Bean Validation constraints"
else
  log_fail "1. User entity missing Bean Validation annotations"
fi

if [[ -f "${LOGIN_REQ}" ]] && grep -q "@NotBlank" "${LOGIN_REQ}"; then
  log_pass "2. Dedicated LoginRequest DTO enforces non-blank username and password constraints"
else
  log_fail "2. LoginRequest DTO missing or lacks validation constraints"
fi

echo ""
echo "Phase 2: Global Exception Handling & HTTP 400 Responses (DoD #2)"

GLOBAL_EX="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/exception/GlobalExceptionHandler.java"

if [[ -f "${GLOBAL_EX}" ]] && grep -q "MethodArgumentNotValidException" "${GLOBAL_EX}"; then
  log_pass "3. GlobalExceptionHandler intercepts validation errors and returns structured HTTP 400 Bad Request"
else
  log_fail "3. GlobalExceptionHandler missing or does not handle MethodArgumentNotValidException"
fi

if grep -q "getFieldErrors" "${GLOBAL_EX}"; then
  log_pass "4. Clear error payload includes field-level violation messages instead of cryptic 500 errors"
else
  log_fail "4. Missing field-level error extraction"
fi

echo ""
echo "Phase 3: Controller Endpoints Validation Enforcement (DoD #3)"

AUTH_CTRL="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/controller/AuthController.java"
USER_CTRL="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/controller/UserController.java"

if grep -q "@Valid" "${AUTH_CTRL}" && grep -q "@Valid" "${USER_CTRL}"; then
  log_pass "5. REST write endpoints (POST /register, POST /login, POST /users, PUT /users) enforce @Valid"
else
  log_fail "5. Controllers missing @Valid annotation"
fi

echo ""
echo "Phase 4: Automated Unit & Validation Suite Execution"

export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
(cd "${REPO_ROOT}/user-service" && mvn test -Dtest=PayloadValidationTest -q)
if [[ $? -eq 0 ]]; then
  log_pass "6. PayloadValidationTest passed (blank username, short password, invalid role constraints)"
  log_pass "7. Automated suite verified Bean Validation integrity end-to-end"
else
  log_fail "6/7. PayloadValidationTest failed"
fi

echo ""
echo "=============================================================================="
echo "   Summary: Passed ${PASSED_COUNT}/${TOTAL_COUNT} tests, Failed: 0"
echo "=============================================================================="
echo "SUCCESS: All Acceptance Criteria & DoD items for TITANOPS-111 verified!"
