#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Prometheus Scrape Config & Microservice Discovery Verification
# Ticket: TITANOPS-74: Port existing prometheus.yml scrape config into EKS
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
echo -e "${BLUE}   TitanOps HMS: Prometheus Microservices Scrape Verification (TITANOPS-74)   ${NC}"
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
PROM_CONFIG="${REPO_DIR}/k8s/monitoring/prometheus/02-prometheus-configmap.yaml"
HELM_VALUES="${REPO_DIR}/k8s/monitoring/prometheus/helm-values.yaml"
DEPLOY_DIR="${REPO_DIR}/k8s/deployments"
DOC_FILE="${REPO_DIR}/docs/PROMETHEUS-SCRAPE-CONFIG.md"

echo -e "${YELLOW}Phase 1: Dynamic Kubernetes Service Discovery Verification${NC}"

check "1. Prometheus ConfigMap defines dynamic SD job for microservices in hms namespace" \
    "grep -q 'job_name:.*titanops-microservices-sd' '${PROM_CONFIG}' && \
     grep -q 'role: endpoints' '${PROM_CONFIG}' && \
     grep -q 'namespaces:' '${PROM_CONFIG}' && \
     grep -q -- '- hms' '${PROM_CONFIG}'"

check "2. Service discovery relabels metrics_path to /actuator/prometheus" \
    "grep -q 'target_label: __metrics_path__' '${PROM_CONFIG}' && \
     grep -q 'replacement: /actuator/prometheus' '${PROM_CONFIG}'"

echo -e "\n${YELLOW}Phase 2: Ported Scrape Jobs for All 9 Services & OTel Collector${NC}"

check "3. Ported scrape config includes all 9 microservices with in-cluster DNS" \
    "grep -q 'patient-service.hms.svc.cluster.local:8081' '${PROM_CONFIG}' && \
     grep -q 'user-service.hms.svc.cluster.local:8082' '${PROM_CONFIG}' && \
     grep -q 'appointment-service.hms.svc.cluster.local:8083' '${PROM_CONFIG}' && \
     grep -q 'provider-service.hms.svc.cluster.local:8084' '${PROM_CONFIG}' && \
     grep -q 'encounter-service.hms.svc.cluster.local:8085' '${PROM_CONFIG}' && \
     grep -q 'billing-service.hms.svc.cluster.local:8086' '${PROM_CONFIG}' && \
     grep -q 'lab-service.hms.svc.cluster.local:8087' '${PROM_CONFIG}' && \
     grep -q 'medication-service.hms.svc.cluster.local:8088' '${PROM_CONFIG}' && \
     grep -q 'prescription-service.hms.svc.cluster.local:8089' '${PROM_CONFIG}'"

check "4. Ported scrape config includes otel-collector metrics target on port 8889" \
    "grep -q 'job_name:.*otel-collector' '${PROM_CONFIG}' && \
     grep -q 'otel-collector.hms.svc.cluster.local:8889' '${PROM_CONFIG}'"

echo -e "\n${YELLOW}Phase 3: Microservice Service Manifest Annotations${NC}"

check "5. All 9 microservices annotated with prometheus.io/scrape and /actuator/prometheus" \
    "grep -rq 'prometheus.io/scrape: \"true\"' '${DEPLOY_DIR}' && \
     grep -rq 'prometheus.io/path: \"/actuator/prometheus\"' '${DEPLOY_DIR}' && \
     [ \$(grep -rc 'prometheus.io/scrape: \"true\"' '${DEPLOY_DIR}' | grep -v ':0' | wc -l) -ge 9 ]"

echo -e "\n${YELLOW}Phase 4: Helm Values & Architecture Documentation${NC}"

check "6. Production helm-values.yaml configures additionalScrapeConfigs for SD" \
    "grep -q 'additionalScrapeConfigs:' '${HELM_VALUES}' && \
     grep -q 'job_name:.*titanops-microservices-sd' '${HELM_VALUES}'"

check "7. Architecture documentation exists detailing ported scrape configs" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: In-Cluster Prometheus Scrape Configuration' '${DOC_FILE}' && \
     grep -q 'Service Discovery' '${DOC_FILE}' && \
     grep -q '/actuator/prometheus' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All Prometheus scrape config porting tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
