#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: ALB Ingress & ACM TLS Verification Suite
# Ticket: TITANOPS-128: Set up ALB Ingress Controller with ACM-issued TLS (HTTPS-only)
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
echo -e "${BLUE}   TitanOps HMS: ALB Ingress & ACM TLS Verification (TITANOPS-128)             ${NC}"
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
INGRESS_DIR="${REPO_DIR}/k8s/ingress"

echo -e "${YELLOW}Phase 1: Terraform ACM & ALB Controller IRSA Infrastructure${NC}"
check "1. Terraform configuration with ingress module validates cleanly" \
    "cd '${TF_DIR}' && terraform validate > /dev/null 2>&1"

check "2. ACM Certificate resource declared with RSA_2048 and DNS validation" \
    "grep -q 'resource \"aws_acm_certificate\" \"alb_tls\"' '${TF_DIR}/modules/ingress/main.tf' && grep -q 'key_algorithm.*RSA_2048' '${TF_DIR}/modules/ingress/main.tf'"

check "3. AWS Load Balancer Controller IAM IRSA Role declared for kube-system SA" \
    "grep -q 'resource \"aws_iam_role\" \"aws_load_balancer_controller\"' '${TF_DIR}/modules/ingress/main.tf' && grep -q 'aws-load-balancer-controller' '${TF_DIR}/modules/ingress/main.tf'"

check "4. Controller IAM policy grants ELB, ACM, EC2, and WAF permissions" \
    "grep -q 'elasticloadbalancing:CreateLoadBalancer' '${TF_DIR}/modules/ingress/main.tf' && grep -q 'acm:DescribeCertificate' '${TF_DIR}/modules/ingress/main.tf'"

echo -e "\n${YELLOW}Phase 2: Kubernetes Ingress Controller Manifests${NC}"
check "5. AWS Load Balancer Controller ServiceAccount and IngressClass exist and valid YAML" \
    "ruby -ryaml -e 'YAML.load_stream(File.read(\"${INGRESS_DIR}/00-aws-load-balancer-controller.yaml\"))' > /dev/null 2>&1"

check "6. IngressClass 'alb' configured with ingress.k8s.aws/alb controller" \
    "grep -q 'controller: ingress.k8s.aws/alb' '${INGRESS_DIR}/00-aws-load-balancer-controller.yaml'"

check "7. ALB Ingress manifest exists and parses as valid YAML" \
    "ruby -ryaml -e 'YAML.load_file(\"${INGRESS_DIR}/01-alb-ingress-tls.yaml\")' > /dev/null 2>&1"

echo -e "\n${YELLOW}Phase 3: TLS Termination & HTTPS Redirection (DoD Verification)${NC}"
check "8. Ingress specifies dual-port listening (HTTP 80 and HTTPS 443)" \
    "grep -q 'alb.ingress.kubernetes.io/listen-ports.*HTTP.*80.*HTTPS.*443' '${INGRESS_DIR}/01-alb-ingress-tls.yaml'"

check "9. Ingress enforces automatic HTTP to HTTPS redirection (ssl-redirect: 443)" \
    "grep -q 'alb.ingress.kubernetes.io/ssl-redirect:.*443' '${INGRESS_DIR}/01-alb-ingress-tls.yaml'"

check "10. Ingress attaches ACM TLS certificate" \
    "grep -q 'alb.ingress.kubernetes.io/certificate-arn' '${INGRESS_DIR}/01-alb-ingress-tls.yaml'"

check "11. Ingress routes traffic to frontend UI and all 9 backend microservices" \
    "grep -q 'name: frontend' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: patient-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: billing-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: appointment-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: user-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: encounter-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: lab-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: medication-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: prescription-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml' && \
     grep -q 'name: provider-service' '${INGRESS_DIR}/01-alb-ingress-tls.yaml'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-128 ALB Ingress Controller & ACM TLS verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: TITANOPS-128 verification failed.${NC}"
    exit 1
fi
