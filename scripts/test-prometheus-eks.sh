#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Prometheus EKS Installation Verification Suite
# Ticket: TITANOPS-39: Install and configure Prometheus in the EKS cluster
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
echo -e "${BLUE}   TitanOps HMS: Prometheus EKS Deployment Verification (TITANOPS-39)         ${NC}"
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
PROM_DIR="${REPO_DIR}/k8s/monitoring/prometheus"
DOC_FILE="${REPO_DIR}/docs/PROMETHEUS-EKS-SETUP.md"

echo -e "${YELLOW}Phase 1: Manifest Integrity & Kustomize Build${NC}"

check "1. Prometheus manifests and Helm values files exist in repository" \
    "[ -f '${PROM_DIR}/01-prometheus-rbac.yaml' ] && \
     [ -f '${PROM_DIR}/02-prometheus-configmap.yaml' ] && \
     [ -f '${PROM_DIR}/03-prometheus-deployment.yaml' ] && \
     [ -f '${PROM_DIR}/04-prometheus-service.yaml' ] && \
     [ -f '${PROM_DIR}/helm-values.yaml' ] && \
     [ -f '${PROM_DIR}/kustomization.yaml' ]"

check "2. Kustomize builds monitoring/prometheus bundle cleanly" \
    "kubectl kustomize '${PROM_DIR}' > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 2: RBAC & Security Hardening${NC}"

check "3. RBAC ClusterRole grants node, pod, endpoint, and metric scrape permissions" \
    "grep -q 'ClusterRole' '${PROM_DIR}/01-prometheus-rbac.yaml' && \
     grep -q 'nodes/metrics' '${PROM_DIR}/01-prometheus-rbac.yaml' && \
     grep -q 'nonResourceURLs' '${PROM_DIR}/01-prometheus-rbac.yaml' && \
     grep -q 'prometheus-k8s' '${PROM_DIR}/01-prometheus-rbac.yaml'"

check "4. Prometheus Deployment enforces non-root UID 65534 and dropped capabilities" \
    "grep -q 'runAsNonRoot: true' '${PROM_DIR}/03-prometheus-deployment.yaml' && \
     grep -q 'runAsUser: 65534' '${PROM_DIR}/03-prometheus-deployment.yaml' && \
     grep -q 'drop:' '${PROM_DIR}/03-prometheus-deployment.yaml' && \
     grep -q 'prom/prometheus' '${PROM_DIR}/03-prometheus-deployment.yaml'"

echo -e "\n${YELLOW}Phase 3: Scrape Configuration & Target Discovery${NC}"

check "5. Prometheus ConfigMap defines node, kube-apiserver, and cAdvisor scrape jobs" \
    "grep -q 'job_name:.*kubernetes-nodes' '${PROM_DIR}/02-prometheus-configmap.yaml' && \
     grep -q 'job_name:.*kubernetes-cadvisor' '${PROM_DIR}/02-prometheus-configmap.yaml' && \
     grep -q 'job_name:.*kubernetes-apiservers' '${PROM_DIR}/02-prometheus-configmap.yaml' && \
     grep -q 'job_name:.*kubernetes-service-endpoints' '${PROM_DIR}/02-prometheus-configmap.yaml'"

check "6. Prometheus Service exposes web UI and query endpoint on port 9090" \
    "grep -q 'port: 9090' '${PROM_DIR}/04-prometheus-service.yaml' && \
     grep -q 'name: web' '${PROM_DIR}/04-prometheus-service.yaml'"

check "7. Scrape and operational configuration stored as code in helm-values.yaml" \
    "grep -q 'retention: 15d' '${PROM_DIR}/helm-values.yaml' && \
     grep -q 'nodeExporter:' '${PROM_DIR}/helm-values.yaml' && \
     grep -q 'kubeStateMetrics:' '${PROM_DIR}/helm-values.yaml'"

echo -e "\n${YELLOW}Phase 4: Architecture Documentation${NC}"

check "8. Prometheus deployment and architecture documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: Prometheus Installation & Configuration in EKS' '${DOC_FILE}' && \
     grep -q 'Service Discovery' '${DOC_FILE}' && \
     grep -q 'Port Forwarding' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All Prometheus EKS deployment tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
