# AWS WAFv2 Application Load Balancer Protection & Attack Mitigation
**Ticket Reference:** `TITANOPS-129`  
**Author:** Siddhesh Bhandarkar (`sibh8`) / Platform Engineering  
**Components:** `terraform/modules/waf/`, `k8s/ingress/01-alb-ingress-tls.yaml`

---

## 1. Executive Summary

Electronic Protected Health Information (ePHI) hosted within TitanOps HMS requires protection against automated bots, layer 7 DDoS floods, OWASP Top 10 web application vulnerabilities, and SQL injection exploits.

`TITANOPS-129` provisions an AWS WAFv2 WebACL attached directly to the public Application Load Balancer via the AWS Load Balancer Controller Ingress annotations.

---

## 2. Infrastructure as Code (Terraform)

Located in `terraform/modules/waf/`:
- **WebACL Scope**: `REGIONAL` (for AWS ALB in the application VPC).
- **Default Action**: `allow` (permit legitimate traffic).
- **Managed Rule Groups Enabled**:
  1. **AWSManagedRulesCommonRuleSet** (Priority 10): Covers standard OWASP vulnerabilities including cross-site scripting (XSS), command injection, and local file inclusion (LFI).
  2. **AWSManagedRulesKnownBadInputsRuleSet** (Priority 20): Inspects request headers and payloads for known malicious exploits, probing strings, and bad user agents.
  3. **AWSManagedRulesSQLiRuleSet** (Priority 30): Scans query arguments, body payloads, and authorization headers for SQL injection keywords, comment markers, and boolean evasion attempts.
  4. **RateLimitPerIP** (Priority 40): Enforces a hard threshold of 2,000 requests per 5-minute rolling window per IP to stop layer 7 denial-of-service flooding.
- **Audit & Security Logging**:
  - `aws_cloudwatch_log_group.waf_logs`: Prefix `aws-waf-logs-` archiving filtered events with a 30-day retention window.
  - Logging filter configured to retain and stream all `BLOCK` actions.

---

## 3. Kubernetes ALB Ingress Integration

Configured in `k8s/ingress/01-alb-ingress-tls.yaml`:
```yaml
annotations:
  alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:ap-south-1:123456789012:regional/webacl/titanops-dev-alb-waf
```
The AWS Load Balancer Controller associates the regional WebACL with the provisioned Application Load Balancer automatically upon ingress reconciliation.

---

## 4. Verification and Malicious Payload Simulation

The automated test script `scripts/test-aws-waf-alb.sh` validates:
- Terraform WAF module syntax and provider configuration.
- Regional WebACL declarations and all 3 AWS Managed Rule Sets.
- Rate-limiting volumetric rule definition.
- CloudWatch logging configuration for blocked request auditing.
- Ingress annotation attachment syntax.
- Simulated evaluation of SQL injection vectors (`' OR '1'='1`, `UNION SELECT`) and malicious script injections (`<script>alert(1)</script>`, `../../etc/passwd`).

Execution:
```bash
./scripts/test-aws-waf-alb.sh
```
All 10 automated checks pass.
