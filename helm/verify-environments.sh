#!/usr/bin/env bash
# ==============================================================================
# Automated Verification Suite for Helm Environment Parameterization (TITANOPS-50)
# Team: TitanOps (Platform Engineering)
# Description: Validates multi-environment Helm values (dev, staging, prod)
#              against DoD criteria: linting, templating diffs, and zero hardcoded values.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHART_DIR="$ROOT_DIR/helm/titanops-base"
VALUES_DIR="$ROOT_DIR/helm/values"
ENV_DIR="$ROOT_DIR/helm/environments"

PASSED=0
FAILED=0

assert_equals() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  [PASS] $label"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] $label (Expected: '$expected', Got: '$actual')"
        FAILED=$((FAILED + 1))
    fi
}

assert_contains() {
    local label="$1"
    local needle="$2"
    local haystack="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo "  [PASS] $label"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] $label (Expected to find: '$needle')"
        FAILED=$((FAILED + 1))
    fi
}

assert_not_contains() {
    local label="$1"
    local needle="$2"
    local haystack="$3"
    if ! echo "$haystack" | grep -q "$needle"; then
        echo "  [PASS] $label"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] $label (Expected NOT to find: '$needle')"
        FAILED=$((FAILED + 1))
    fi
}

echo "======================================================================"
echo " TITANOPS-50: Helm Environment Parameterization Verification Suite"
echo " Target Chart : $CHART_DIR"
echo "======================================================================"

# ── 1. File Existence Checks (DoD #1) ─────────────────────────────────────────
echo ""
echo "[Test Suite 1: File Existence & Multi-Environment Directory Structure]"
for f in "$ROOT_DIR/helm/values-dev.yaml" "$ROOT_DIR/helm/values-staging.yaml" "$ROOT_DIR/helm/values-prod.yaml" \
         "$ENV_DIR/dev/values.yaml" "$ENV_DIR/staging/values.yaml" "$ENV_DIR/prod/values.yaml"; do
    if [ -f "$f" ]; then
        echo "  [PASS] File exists: ${f#$ROOT_DIR/}"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] Missing file: ${f#$ROOT_DIR/}"
        FAILED=$((FAILED + 1))
    fi
done

# ── 2. Helm Linting Checks ────────────────────────────────────────────────────
echo ""
echo "[Test Suite 2: Helm Linting Across Environments]"
for env_file in "$ROOT_DIR/helm/values-dev.yaml" "$ROOT_DIR/helm/values-staging.yaml" "$ROOT_DIR/helm/values-prod.yaml"; do
    env_name="$(basename "$env_file" .yaml)"
    if helm lint "$CHART_DIR" -f "$env_file" > /dev/null 2>&1; then
        echo "  [PASS] helm lint passed for $env_name"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] helm lint failed for $env_name"
        FAILED=$((FAILED + 1))
    fi
done

# ── 3. Template Verification - Dev Environment (DoD #2) ────────────────────────
echo ""
echo "[Test Suite 3: Dev Environment Manifest Assertions]"
DEV_MANIFEST=$(helm template patient-service "$CHART_DIR" -f "$VALUES_DIR/patient-service.yaml" -f "$ROOT_DIR/helm/values-dev.yaml")

assert_contains "Dev environment label present" "app.kubernetes.io/environment: \"dev\"" "$DEV_MANIFEST"
assert_contains "Dev single replica explicitly configured" "replicas: 1" "$DEV_MANIFEST"
assert_contains "Dev minimal CPU limit (250m)" "cpu: 250m" "$DEV_MANIFEST"
assert_contains "Dev minimal memory limit (512Mi)" "memory: 512Mi" "$DEV_MANIFEST"
assert_contains "Dev debug root logging active" "value: \"DEBUG\"" "$DEV_MANIFEST"
assert_contains "Dev Spring profile set to dev" "value: \"dev\"" "$DEV_MANIFEST"
assert_contains "Dev Ingress host dev.medicore.titanops.io" "host: \"dev.medicore.titanops.io\"" "$DEV_MANIFEST"
assert_not_contains "Dev disables HPA" "kind: HorizontalPodAutoscaler" "$DEV_MANIFEST"
assert_not_contains "Dev disables PodDisruptionBudget" "kind: PodDisruptionBudget" "$DEV_MANIFEST"

# ── 4. Template Verification - Staging Environment (DoD #2) ───────────────────
echo ""
echo "[Test Suite 4: Staging Environment Manifest Assertions]"
STAGING_MANIFEST=$(helm template patient-service "$CHART_DIR" -f "$VALUES_DIR/patient-service.yaml" -f "$ROOT_DIR/helm/values-staging.yaml")

assert_contains "Staging environment label present" "app.kubernetes.io/environment: \"staging\"" "$STAGING_MANIFEST"
assert_contains "Staging 2 replicas configured for HA testing" "replicas: 2" "$STAGING_MANIFEST"
assert_contains "Staging CPU limit (500m)" "cpu: 500m" "$STAGING_MANIFEST"
assert_contains "Staging memory limit (1024Mi)" "memory: 1024Mi" "$STAGING_MANIFEST"
assert_contains "Staging Ingress host staging.medicore.titanops.io" "host: \"staging.medicore.titanops.io\"" "$STAGING_MANIFEST"
assert_contains "Staging TLS secret enabled" "secretName: medicore-staging-tls-secret" "$STAGING_MANIFEST"
assert_contains "Staging PodDisruptionBudget active (minAvailable: 1)" "minAvailable: 1" "$STAGING_MANIFEST"
assert_contains "Staging PodAntiAffinity configured" "podAntiAffinity:" "$STAGING_MANIFEST"
assert_not_contains "Staging disables HPA" "kind: HorizontalPodAutoscaler" "$STAGING_MANIFEST"

# ── 5. Template Verification - Production Environment (DoD #2) ────────────────
echo ""
echo "[Test Suite 5: Production Environment Manifest Assertions]"
PROD_MANIFEST=$(helm template patient-service "$CHART_DIR" -f "$VALUES_DIR/patient-service.yaml" -f "$ROOT_DIR/helm/values-prod.yaml")

assert_contains "Prod environment label present" "app.kubernetes.io/environment: \"prod\"" "$PROD_MANIFEST"
assert_not_contains "Prod delegates replicas to HPA (no static replicaCount in Deployment)" "replicas: 3" "$PROD_MANIFEST"
assert_contains "Prod HPA enabled with min 3 replicas" "minReplicas: 3" "$PROD_MANIFEST"
assert_contains "Prod HPA enabled with max 10 replicas" "maxReplicas: 10" "$PROD_MANIFEST"
assert_contains "Prod HPA CPU target 70%" "averageUtilization: 70" "$PROD_MANIFEST"
assert_contains "Prod HPA Memory target 80%" "averageUtilization: 80" "$PROD_MANIFEST"
assert_contains "Prod PodDisruptionBudget enabled (minAvailable: 2)" "minAvailable: 2" "$PROD_MANIFEST"
assert_contains "Prod production CPU request (250m)" "cpu: 250m" "$PROD_MANIFEST"
assert_contains "Prod production CPU limit (1000m)" "cpu: 1000m" "$PROD_MANIFEST"
assert_contains "Prod production Memory limit (2048Mi)" "memory: 2048Mi" "$PROD_MANIFEST"
assert_contains "Prod Ingress host medicore.titanops.io" "host: \"medicore.titanops.io\"" "$PROD_MANIFEST"
assert_contains "Prod Ingress WAF ACL protection" "alb.ingress.kubernetes.io/wafv2-acl-arn:" "$PROD_MANIFEST"
assert_contains "Prod Ingress TLS secret enabled" "secretName: medicore-prod-tls-secret" "$PROD_MANIFEST"
assert_contains "Prod Spring profile set to prod" "value: \"prod\"" "$PROD_MANIFEST"
assert_contains "Prod root log level set to WARN" "value: \"WARN\"" "$PROD_MANIFEST"
assert_contains "Prod topology spread constraint for multi-AZ HA" "topologyKey: topology.kubernetes.io/zone" "$PROD_MANIFEST"
assert_contains "Prod required pod anti-affinity" "requiredDuringSchedulingIgnoredDuringExecution:" "$PROD_MANIFEST"

# ── 6. Check for Zero Hardcoded Values in Templates (DoD #3) ──────────────────
echo ""
echo "[Test Suite 6: Verify Zero Hardcoded Environment Strings in Templates]"
HARDCODED_MATCHES=$(grep -rnE "(dev|staging|prod)" "$CHART_DIR/templates" || true)
if [ -z "$HARDCODED_MATCHES" ]; then
    echo "  [PASS] Zero hardcoded environment strings in $CHART_DIR/templates"
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Found hardcoded environment strings in templates:"
    echo "$HARDCODED_MATCHES"
    FAILED=$((FAILED + 1))
fi

# ── 7. Multi-Service Layering Verification across all 10 services ─────────────
echo ""
echo "[Test Suite 7: Multi-Service Layering with Environment Values]"
SERVICES=("appointment-service" "billing-service" "encounter-service" "frontend" \
          "lab-service" "medication-service" "patient-service" "prescription-service" \
          "provider-service" "user-service")

for svc in "${SERVICES[@]}"; do
    if helm template "$svc" "$CHART_DIR" -f "$VALUES_DIR/${svc}.yaml" -f "$ROOT_DIR/helm/values-prod.yaml" > /dev/null 2>&1; then
        echo "  [PASS] Layered templating succeeded for $svc (prod)"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] Layered templating failed for $svc (prod)"
        FAILED=$((FAILED + 1))
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "======================================================================"
echo " Verification Complete: $PASSED passed, $FAILED failed"
echo "======================================================================"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
