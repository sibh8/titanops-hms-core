#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Post-Deploy Integration Verification Job Test Suite
# Ticket: TITANOPS-73: Wire Node.js test suite into GitHub Actions as post-deploy
# ==============================================================================
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   TitanOps HMS: Post-Deploy Integration Job Verification (TITANOPS-73)       ${NC}"
echo -e "${BLUE}==============================================================================${NC}\n"

check() {
    local test_name="$1"
    local condition="$2"
    if eval "$condition"; then
        echo -e "  [${GREEN}PASS${NC}] ${test_name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  [${RED}FAIL${NC}] ${test_name}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="${REPO_DIR}/.github/workflows/ci-cd.yml"
TESTS_DIR="${REPO_DIR}/integration-tests"
DOC_FILE="${REPO_DIR}/docs/POST-DEPLOY-INTEGRATION-TESTS.md"

echo -e "${YELLOW}Phase 1: CI/CD Workflow Job Definition${NC}"

check "1. post-deploy-integration-tests job defined in ci-cd.yml" \
    "grep -q 'post-deploy-integration-tests:' '${WORKFLOW}'"

check "2. Job explicitly declares dependency on deployment (needs: [deploy])" \
    "grep -A 5 'post-deploy-integration-tests:' '${WORKFLOW}' | grep -q 'needs: \[deploy\]'"

check "3. Job enforces conditional execution only on successful deployment" \
    "grep -A 7 'post-deploy-integration-tests:' '${WORKFLOW}' | grep -q 'if: needs.deploy.result == .success.'"

echo -e "\n${YELLOW}Phase 2: Test Execution & Artifact Upload${NC}"

check "4. Job executes run-tests.sh test runner" \
    "grep -q './run-tests.sh' '${WORKFLOW}'"

check "5. Job uploads test report log as GitHub Actions artifact" \
    "grep -q 'actions/upload-artifact' '${WORKFLOW}' && \
     grep -q 'integration-test-reports' '${WORKFLOW}'"

echo -e "\n${YELLOW}Phase 3: Integration Test Suite Completeness${NC}"

check "6. Integration test directory contains all 11 test suites (00-health to 10-cross-service)" \
    "[ -f '${TESTS_DIR}/tests/00-health.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/01-users.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/02-providers.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/03-patients.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/04-appointments.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/05-encounters.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/06-lab.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/07-medications.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/08-prescriptions.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/09-billing.test.js' ] && \
     [ -f '${TESTS_DIR}/tests/10-cross-service.test.js' ]"

check "7. Test runner script run-tests.sh is executable and syntax valid" \
    "[ -x '${TESTS_DIR}/run-tests.sh' ] && \
     bash -n '${TESTS_DIR}/run-tests.sh'"

echo -e "\n${YELLOW}Phase 4: Architecture Documentation${NC}"

check "8. Post-deploy integration testing documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: Post-Deploy Integration Verification Job' '${DOC_FILE}' && \
     grep -q 'needs: \[deploy\]' '${DOC_FILE}' && \
     grep -q 'Artifact Upload' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All post-deploy integration job tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
