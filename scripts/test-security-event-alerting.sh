#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Security Event Alerting Verification Suite
# Ticket: TITANOPS-134: Add alerting for security events
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
echo -e "${BLUE}   TitanOps HMS: Security Event Alerting Verification (TITANOPS-134)          ${NC}"
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
TF_DIR="${REPO_DIR}/terraform"
ALERT_MODULE="${TF_DIR}/modules/security_alerts"
K8S_RULES="${REPO_DIR}/k8s/monitoring/security-alerting-rules.yaml"
DOC_FILE="${REPO_DIR}/docs/SECURITY-EVENT-ALERTING.md"

echo -e "${YELLOW}Phase 1: Terraform Infrastructure & Event Routing Verification${NC}"

check "1. Terraform configuration with security alerts module validates cleanly" \
    "cd '${TF_DIR}' && terraform get > /dev/null 2>&1 && terraform validate > /dev/null 2>&1"

check "2. SNS topic resource created for centralized security notifications" \
    "grep -q 'resource \"aws_sns_topic\" \"security_alerts\"' '${ALERT_MODULE}/main.tf' && \
     grep -q 'aws_sns_topic_policy' '${ALERT_MODULE}/main.tf'"

check "3. EventBridge rule captures High and Critical GuardDuty security findings (severity >= 7.0)" \
    "grep -q 'aws_cloudwatch_event_rule' '${ALERT_MODULE}/main.tf' && \
     grep -q 'source.*aws.guardduty' '${ALERT_MODULE}/main.tf' && \
     grep -q 'detail-type.*GuardDuty Finding' '${ALERT_MODULE}/main.tf' && \
     grep -q 'severity' '${ALERT_MODULE}/main.tf'"

check "4. EventBridge target forwards GuardDuty findings directly to security SNS topic" \
    "grep -q 'aws_cloudwatch_event_target' '${ALERT_MODULE}/main.tf' && \
     grep -q 'aws_sns_topic.security_alerts.arn' '${ALERT_MODULE}/main.tf'"

check "5. CloudWatch metric alarm monitors HTTP 401/403 authentication failure spikes" \
    "grep -q 'aws_cloudwatch_metric_alarm.*auth_failure_spike' '${ALERT_MODULE}/main.tf' && \
     grep -q 'HTTPCode_Target_4XX_Count' '${ALERT_MODULE}/main.tf' && \
     grep -q 'AWS/ApplicationELB' '${ALERT_MODULE}/main.tf'"

check "6. CloudWatch metric alarm monitors AWS WAF blocked request spikes" \
    "grep -q 'aws_cloudwatch_metric_alarm.*waf_block_spike' '${ALERT_MODULE}/main.tf' && \
     grep -q 'BlockedRequests' '${ALERT_MODULE}/main.tf' && \
     grep -q 'AWS/WAFV2' '${ALERT_MODULE}/main.tf'"

check "7. Root Terraform main.tf and outputs.tf expose security alert outputs" \
    "grep -q 'module \"security_alerts\"' '${TF_DIR}/main.tf' && \
     grep -q 'output \"security_alerts_topic_arn\"' '${TF_DIR}/outputs.tf' && \
     grep -q 'output \"auth_failure_alarm_arn\"' '${TF_DIR}/outputs.tf'"

echo -e "\n${YELLOW}Phase 2: In-Cluster Prometheus & Runtime Security Alerting${NC}"

check "8. Kubernetes PrometheusRule file exists and defines valid security alert rules" \
    "[ -f '${K8S_RULES}' ] && \
     grep -q 'kind: PrometheusRule' '${K8S_RULES}' && \
     grep -q 'HighAuthFailureRate' '${K8S_RULES}' && \
     grep -q 'WAFBlockRateSpike' '${K8S_RULES}' && \
     grep -q 'ContainerRunningAsRoot' '${K8S_RULES}' && \
     grep -q 'ExcessiveKubeApiDeniedRequests' '${K8S_RULES}'"

echo -e "\n${YELLOW}Phase 3: Security Alerting Architecture Documentation${NC}"

check "9. Security alerting architecture and incident runbook documentation exists" \
    "[ -f '${DOC_FILE}' ] && \
     grep -q '# TitanOps HMS: Security Event Alerting' '${DOC_FILE}' && \
     grep -q 'EventBridge' '${DOC_FILE}' && \
     grep -q 'GuardDuty' '${DOC_FILE}' && \
     grep -q 'CloudWatch' '${DOC_FILE}'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}All security event alerting tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Some security event alerting tests failed.${NC}"
    exit 1
fi
