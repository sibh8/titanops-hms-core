#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: K8s Microservices Manifests Verification Suite
# Ticket: TITANOPS-69 (and subtasks TITANOPS-86 through TITANOPS-94)
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
echo -e "${BLUE}   TitanOps HMS: K8s Microservices Manifests Verification (TITANOPS-69)       ${NC}"
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
K8S_DIR="${REPO_DIR}/k8s/deployments"

echo -e "${YELLOW}Phase 1: Manifest Presence & YAML Parsing (All 9 Services)${NC}"
SERVICES=(
    "01-patient-service.yaml:patient-service:8081"
    "02-appointment-service.yaml:appointment-service:8082"
    "03-user-service.yaml:user-service:8083"
    "04-billing-service.yaml:billing-service:8084"
    "05-encounter-service.yaml:encounter-service:8085"
    "06-lab-service.yaml:lab-service:8086"
    "07-medication-service.yaml:medication-service:8087"
    "08-prescription-service.yaml:prescription-service:8088"
    "09-provider-service.yaml:provider-service:8089"
)

for entry in "${SERVICES[@]}"; do
    IFS=":" read -r file name port <<< "${entry}"
    check "Manifest file exists: ${file}" \
        "[ -f '${K8S_DIR}/${file}' ]"
    check "YAML syntax valid for ${file}" \
        "ruby -ryaml -e \"YAML.load_stream(File.read('${K8S_DIR}/${file}'))\" > /dev/null 2>&1"
done

echo -e "\n${YELLOW}Phase 2: Deployment Specification & Standards Audit${NC}"
for entry in "${SERVICES[@]}"; do
    IFS=":" read -r file name port <<< "${entry}"
    check "Deployment resource defined in ${file}" \
        "grep -q 'kind: Deployment' '${K8S_DIR}/${file}' && grep -q 'name: ${name}' '${K8S_DIR}/${file}'"
    check "Non-root security context configured in ${file}" \
        "grep -q 'runAsNonRoot: true' '${K8S_DIR}/${file}' && grep -q 'runAsUser: 10001' '${K8S_DIR}/${file}'"
    check "Datasource secret referenced via envFrom in ${file}" \
        "grep -A 2 'envFrom:' '${K8S_DIR}/${file}' | grep -q 'name: titanops-datasource-credentials'"
    check "Resource requests and limits defined in ${file}" \
        "grep -A 5 'resources:' '${K8S_DIR}/${file}' | grep -q 'cpu:'"
    check "Liveness and readiness probes defined in ${file}" \
        "grep -q 'livenessProbe:' '${K8S_DIR}/${file}' && grep -q 'readinessProbe:' '${K8S_DIR}/${file}'"
done

echo -e "\n${YELLOW}Phase 3: Service Specification Audit${NC}"
for entry in "${SERVICES[@]}"; do
    IFS=":" read -r file name port <<< "${entry}"
    check "ClusterIP Service defined on port ${port} in ${file}" \
        "grep -q 'kind: Service' '${K8S_DIR}/${file}' && grep -q 'port: ${port}' '${K8S_DIR}/${file}'"
done

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-69 K8s Microservices manifests verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Verification failed with ${FAIL_COUNT} errors.${NC}"
    exit 1
fi
