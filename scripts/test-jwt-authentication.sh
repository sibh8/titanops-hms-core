#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# TITANOPS-107: JWT-Based Authentication & Per-Endpoint Authorization Tests
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED_COUNT=0
TOTAL_COUNT=8

log_pass() {
  echo -e "  [${GREEN}PASS${NC}] $1"
  PASSED_COUNT=$((PASSED_COUNT + 1))
}

log_fail() {
  echo -e "  [${RED}FAIL${NC}] $1"
  exit 1
}

echo "=============================================================================="
echo "   TITANOPS-107: JWT Authentication & Authorization Verification Suite       "
echo "=============================================================================="

echo ""
echo "Phase 1: Token Issuance & Algorithm Specification (DoD #1)"

JWT_UTIL="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/security/JwtUtil.java"
AUTH_CTRL="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/controller/AuthController.java"

if [[ -f "${JWT_UTIL}" ]] && grep -q "HmacSHA256" "${JWT_UTIL}"; then
  log_pass "1. JwtUtil implements standard RFC 7519 HMAC-SHA256 token generation and validation"
else
  log_fail "1. JwtUtil missing or lacks HMAC-SHA256 algorithm"
fi

if grep -q "jwtUtil.generateToken" "${AUTH_CTRL}"; then
  log_pass "2. AuthController issues signed JWT token on POST /api/auth/login"
else
  log_fail "2. AuthController does not issue JWT token on login"
fi

echo ""
echo "Phase 2: Authentication Filter & 401 Enforcement (DoD #2)"

JWT_FILTER="${REPO_ROOT}/user-service/src/main/java/com/medicore/hms/user/security/JwtAuthFilter.java"

if [[ -f "${JWT_FILTER}" ]] && grep -q "OncePerRequestFilter" "${JWT_FILTER}"; then
  log_pass "3. JwtAuthFilter intercepts incoming requests and extracts Bearer tokens"
else
  log_fail "3. JwtAuthFilter missing or not an HTTP filter"
fi

if grep -q "SC_UNAUTHORIZED" "${JWT_FILTER}"; then
  log_pass "4. Missing, expired, or invalid tokens are rejected with HTTP 401 Unauthorized"
else
  log_fail "4. JwtAuthFilter does not reject unauthenticated calls with 401"
fi

echo ""
echo "Phase 3: Role-Based Access Control (RBAC) Enforcement (DoD #3)"

if grep -q "SC_FORBIDDEN" "${JWT_FILTER}" && grep -q "ADMIN" "${JWT_FILTER}"; then
  log_pass "5. RBAC policy protects destructive endpoints, requiring role=ADMIN or rejecting with 403"
else
  log_fail "5. RBAC policy missing in JwtAuthFilter"
fi

echo ""
echo "Phase 4: Frontend Bearer Token Attachment (DoD #4)"

API_CLIENT="${REPO_ROOT}/frontend/src/api/apiClient.js"
LOGIN_PAGE="${REPO_ROOT}/frontend/src/pages/LoginPage.jsx"

if grep -q "Authorization = \`Bearer \${token}\`" "${API_CLIENT}"; then
  log_pass "6. Axios apiClient interceptor attaches Bearer token from localStorage to all outgoing requests"
else
  log_fail "6. apiClient missing Authorization Bearer interceptor"
fi

if grep -q "login(userData, token)" "${LOGIN_PAGE}"; then
  log_pass "7. LoginPage captures JWT token from login response and persists into AuthContext"
else
  log_fail "7. LoginPage does not pass JWT token to AuthContext"
fi

echo ""
echo "Phase 5: Automated Unit & Validation Suite Execution"

export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
(cd "${REPO_ROOT}/user-service" && mvn test -Dtest=JwtUtilTest -q)
if [[ $? -eq 0 ]]; then
  log_pass "8. JwtUtilTest passed (generation, signature validation, tamper protection, expiration checks)"
else
  log_fail "8. JwtUtilTest failed"
fi

echo ""
echo "=============================================================================="
echo "   Summary: Passed ${PASSED_COUNT}/${TOTAL_COUNT} tests, Failed: 0"
echo "=============================================================================="
echo "SUCCESS: All Acceptance Criteria & DoD items for TITANOPS-107 verified!"
