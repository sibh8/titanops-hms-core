#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: K8s Frontend Manifest Verification Suite
# Ticket: TITANOPS-70: Write K8s Deployment + Service manifest for frontend
# ==============================================================================
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   TitanOps HMS: K8s Frontend Manifest Verification (TITANOPS-70)             ${NC}"
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
FRONTEND_MANIFEST="${REPO_DIR}/k8s/deployments/10-frontend.yaml"

echo -e "${YELLOW}Phase 1: Manifest Presence & YAML Parsing${NC}"
check "1. Frontend manifest file exists" \
    "[ -f '${FRONTEND_MANIFEST}' ]"

check "2. Multi-document YAML syntax parses cleanly" \
    "ruby -ryaml -e \"YAML.load_stream(File.read('${FRONTEND_MANIFEST}'))\" > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 2: Deployment Specification & Hardening${NC}"
check "3. Deployment defines 2 replicas for high availability" \
    "grep -q 'replicas: 2' '${FRONTEND_MANIFEST}'"

check "4. Non-root security context configured for Nginx user (UID 101)" \
    "grep -q 'runAsNonRoot: true' '${FRONTEND_MANIFEST}' && grep -q 'runAsUser: 101' '${FRONTEND_MANIFEST}'"

check "5. Read-only root filesystem enforced with emptyDir mounts" \
    "grep -q 'readOnlyRootFilesystem: true' '${FRONTEND_MANIFEST}' && grep -q 'emptyDir: {}' '${FRONTEND_MANIFEST}'"

check "6. All Linux capabilities dropped" \
    "grep -A 3 'capabilities:' '${FRONTEND_MANIFEST}' | grep -q 'ALL'"

check "7. Resource requests and limits defined" \
    "grep -A 5 'resources:' '${FRONTEND_MANIFEST}' | grep -q 'cpu: 50m' && grep -q 'cpu: 200m' '${FRONTEND_MANIFEST}'"

echo -e "\n${YELLOW}Phase 3: Probes & External Routing Specification${NC}"
check "8. Liveness probe targets /health endpoint" \
    "grep -A 4 'livenessProbe:' '${FRONTEND_MANIFEST}' | grep -q 'path: /health'"

check "9. Readiness probe targets /health endpoint" \
    "grep -A 4 'readinessProbe:' '${FRONTEND_MANIFEST}' | grep -q 'path: /health'"

check "10. Service exposes LoadBalancer on port 80" \
    "grep -q 'type: LoadBalancer' '${FRONTEND_MANIFEST}' && grep -q 'port: 80' '${FRONTEND_MANIFEST}'"

check "11. AWS Load Balancer annotations configured" \
    "grep -q 'service.beta.kubernetes.io/aws-load-balancer-type' '${FRONTEND_MANIFEST}'"

check "12. Ingress resource defines AWS ALB routing" \
    "grep -q 'kind: Ingress' '${FRONTEND_MANIFEST}' && grep -q 'kubernetes.io/ingress.class: \"alb\"' '${FRONTEND_MANIFEST}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-70 K8s Frontend manifest verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
