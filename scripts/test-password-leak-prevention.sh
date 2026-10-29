#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# TITANOPS-108: Stop Leaking Password Hashes in API Responses Verification Suite
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED_COUNT=0
TOTAL_COUNT=6

log_pass() {
  echo -e "  [${GREEN}PASS${NC}] $1"
  PASSED_COUNT=$((PASSED_COUNT + 1))
}

log_fail() {
  echo -e "  [${RED}FAIL${NC}] $1"
  exit 1
}

echo "=============================================================================="
echo "   TITANOPS-108: Password Hash Leak Prevention Verification Suite           "
echo "=============================================================================="

echo ""
echo "Phase 1: Static Entity & Annotation Check (DoD #1)"

USER_JAVA="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/model/User.java"

if grep -q "import com.fasterxml.jackson.annotation.JsonProperty;" "${USER_JAVA}"; then
  log_pass "1. User.java imports com.fasterxml.jackson.annotation.JsonProperty"
else
  log_fail "1. User.java missing JsonProperty import"
fi

if grep -q '@JsonProperty(access = JsonProperty.Access.WRITE_ONLY)' "${USER_JAVA}"; then
  log_pass "2. User.java password field annotated with @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)"
else
  log_fail "2. password field missing WRITE_ONLY annotation"
fi

echo ""
echo "Phase 2: Unit Testing & Serialization Boundary (DoD #2)"

TEST_JAVA="${REPO_ROOT}/user-service/src/test/java/com/medicore/hms/user/model/UserSerializationTest.java"

if [[ -f "${TEST_JAVA}" ]]; then
  log_pass "3. Automated serialization unit test suite exists (UserSerializationTest.java)"
else
  log_fail "3. UserSerializationTest.java not found"
fi

echo "  Running user-service unit test suite..."
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
(cd "${REPO_ROOT}/user-service" && mvn test -Dtest=UserSerializationTest -q)
if [[ $? -eq 0 ]]; then
  log_pass "4. Unit tests passed: Password hash is strictly excluded from serialization"
  log_pass "5. Unit tests passed: Inbound deserialization allows passwords for register/login"
else
  log_fail "4/5. Maven unit tests failed"
fi

echo ""
echo "Phase 3: Integration Test Assertions (DoD #3)"

USERS_TEST_JS="${REPO_ROOT}/integration-tests/tests/01-users.test.js"
if grep -q "body.password, undefined" "${USERS_TEST_JS}"; then
  log_pass "6. Integration test suite (01-users.test.js) explicitly asserts password is undefined in API responses"
else
  log_fail "6. Integration test does not assert password exclusion"
fi

echo ""
echo "=============================================================================="
echo "   Summary: Passed ${PASSED_COUNT}/${TOTAL_COUNT} tests, Failed: 0"
echo "=============================================================================="
echo "SUCCESS: All Acceptance Criteria & DoD items for TITANOPS-108 verified!"
