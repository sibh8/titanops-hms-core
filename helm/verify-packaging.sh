#!/usr/bin/env bash
# ============================================================================
# TITANOPS-52: Verification Suite for Helm Chart Packaging & Publishing
#
# Validates the complete Helm chart packaging, semantic versioning, and
# repository publishing workflow (OCI/ECR and S3 repository).
#
# Definition of Done Assertions:
#   1. Chart is packaged with a semantic version (SemVer 2.0.0)
#   2. Chart is pushed to and retrievable from repository (OCI/ECR or S3)
#   3. helm install from the published chart (not local files) succeeds
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHART_DIR="$REPO_ROOT/helm/titanops-base"
TEST_PORT=5077
TEST_REGISTRY="127.0.0.1:${TEST_PORT}"
TEST_DIR=$(mktemp -d /tmp/titanops-helm-test-XXXXXX)

PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

pass() {
  echo -e "  ${GREEN}[PASS]${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "  ${RED}[FAIL]${NC} $1"
  if [[ -n "${2:-}" ]]; then
    echo -e "         ${RED}$2${NC}"
  fi
  FAIL=$((FAIL + 1))
}

cleanup() {
  if [[ -n "${REGISTRY_PID:-}" ]] && kill -0 "$REGISTRY_PID" 2>/dev/null; then
    kill "$REGISTRY_PID" 2>/dev/null || true
    wait "$REGISTRY_PID" 2>/dev/null || true
  fi
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN} TITANOPS-52: Helm Packaging & Publishing Verification Suite${NC}"
echo -e "${CYAN} Target Chart : ${CHART_DIR}${NC}"
echo -e "${CYAN} Sandbox Dir  : ${TEST_DIR}${NC}"
echo -e "${CYAN}======================================================================${NC}\n"

# ----------------------------------------------------------------------------
# Test Suite 1: Chart Metadata & Semantic Version Specification
# ----------------------------------------------------------------------------
echo -e "${BOLD}[Test Suite 1: Chart Metadata & SemVer Specification]${NC}"

if [[ -f "$CHART_DIR/Chart.yaml" ]]; then
  pass "Chart.yaml exists"
else
  fail "Chart.yaml exists" "Missing $CHART_DIR/Chart.yaml"
fi

CHART_NAME=$(awk -F': ' '/^name:/ {print $2}' "$CHART_DIR/Chart.yaml" | tr -d '"' | tr -d "'" | tr -d ' ')
if [[ "$CHART_NAME" == "titanops-base" ]]; then
  pass "Chart name is 'titanops-base'"
else
  fail "Chart name is 'titanops-base'" "got: $CHART_NAME"
fi

API_VER=$(awk -F': ' '/^apiVersion:/ {print $2}' "$CHART_DIR/Chart.yaml" | tr -d '"' | tr -d "'" | tr -d ' ')
if [[ "$API_VER" == "v2" ]]; then
  pass "Chart apiVersion is 'v2' (Helm 3 specification)"
else
  fail "Chart apiVersion is 'v2'" "got: $API_VER"
fi

CHART_VER=$(awk -F': ' '/^version:/ {print $2}' "$CHART_DIR/Chart.yaml" | tr -d '"' | tr -d "'" | tr -d ' ')
SEMVER_REGEX="^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$"
if [[ "$CHART_VER" =~ $SEMVER_REGEX ]]; then
  pass "Chart version '$CHART_VER' conforms to SemVer 2.0.0"
else
  fail "Chart version conforms to SemVer 2.0.0" "invalid: $CHART_VER"
fi

# ----------------------------------------------------------------------------
# Test Suite 2: Helm Linting
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 2: Helm Linting]${NC}"

if helm_out=$(helm lint "$CHART_DIR" 2>&1); then
  pass "helm lint passed for $CHART_DIR"
else
  fail "helm lint passed for $CHART_DIR" "$helm_out"
fi

# ----------------------------------------------------------------------------
# Test Suite 3: Semantic Version Packaging (DoD Criterion #1)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 3: Semantic Version Packaging (DoD #1)]${NC}"

DIST_DIR="$TEST_DIR/dist"
mkdir -p "$DIST_DIR"

# Package default version (0.1.0)
"$SCRIPT_DIR/publish-chart.sh" \
  --version "0.1.0" \
  --target "local" \
  --output-dir "$DIST_DIR" >/dev/null 2>&1

if [[ -f "$DIST_DIR/titanops-base-0.1.0.tgz" ]]; then
  pass "Packaged default semantic version: titanops-base-0.1.0.tgz"
else
  fail "Packaged default semantic version" "File not found: $DIST_DIR/titanops-base-0.1.0.tgz"
fi

# Package patch bumped version (0.1.1)
"$SCRIPT_DIR/publish-chart.sh" \
  --version "0.1.1" \
  --target "local" \
  --output-dir "$DIST_DIR" >/dev/null 2>&1

if [[ -f "$DIST_DIR/titanops-base-0.1.1.tgz" ]]; then
  pass "Packaged patch semantic version: titanops-base-0.1.1.tgz"
else
  fail "Packaged patch semantic version" "File not found: $DIST_DIR/titanops-base-0.1.1.tgz"
fi

# Package major semver release (1.0.0)
"$SCRIPT_DIR/publish-chart.sh" \
  --version "1.0.0" \
  --app-version "1.0.0" \
  --target "local" \
  --output-dir "$DIST_DIR" >/dev/null 2>&1

if [[ -f "$DIST_DIR/titanops-base-1.0.0.tgz" ]]; then
  pass "Packaged major semantic release: titanops-base-1.0.0.tgz"
else
  fail "Packaged major semantic release" "File not found: $DIST_DIR/titanops-base-1.0.0.tgz"
fi

# Check SHA256 checksum file generation
if [[ -f "$DIST_DIR/titanops-base-0.1.0.tgz.sha256" ]]; then
  pass "SHA256 checksum generated for packaged chart archive"
else
  fail "SHA256 checksum generated for packaged chart archive"
fi

# ----------------------------------------------------------------------------
# Test Suite 4: Archive Integrity & File Layout
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 4: Archive Integrity & File Layout]${NC}"

ARCHIVE_CONTENTS=$(tar -ztvf "$DIST_DIR/titanops-base-0.1.0.tgz")
for expected in "titanops-base/Chart.yaml" "titanops-base/values.yaml" "titanops-base/templates/deployment.yaml" "titanops-base/templates/service.yaml" "titanops-base/templates/_helpers.tpl"; do
  if echo "$ARCHIVE_CONTENTS" | grep -q "$expected"; then
    pass "Archive contains $expected"
  else
    fail "Archive contains $expected" "Missing from package"
  fi
done

# ----------------------------------------------------------------------------
# Test Suite 5: OCI Publishing & Retrieval (DoD Criterion #2)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 5: OCI Registry Publishing & Retrieval (DoD #2)]${NC}"

# Start standalone test OCI registry in background
python3 "$SCRIPT_DIR/test-oci-registry.py" --port "$TEST_PORT" > "$TEST_DIR/registry.log" 2>&1 &
REGISTRY_PID=$!

# Wait for registry to listen
READY=false
for i in {1..20}; do
  if curl -s "http://${TEST_REGISTRY}/v2/" >/dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 0.2
done

if [[ "$READY" == "true" ]]; then
  pass "Test OCI registry server started on $TEST_REGISTRY"
else
  fail "Test OCI registry server started on $TEST_REGISTRY" "Timeout connecting to registry"
fi

# Push 0.1.0 to OCI registry
if push_out=$(helm push "$DIST_DIR/titanops-base-0.1.0.tgz" "oci://${TEST_REGISTRY}/charts" --plain-http 2>&1); then
  pass "Pushed titanops-base-0.1.0 to oci://${TEST_REGISTRY}/charts"
else
  fail "Pushed titanops-base-0.1.0 to OCI" "$push_out"
fi

# Push 1.0.0 to OCI registry
if push_out2=$(helm push "$DIST_DIR/titanops-base-1.0.0.tgz" "oci://${TEST_REGISTRY}/charts" --plain-http 2>&1); then
  pass "Pushed titanops-base-1.0.0 to oci://${TEST_REGISTRY}/charts"
else
  fail "Pushed titanops-base-1.0.0 to OCI" "$push_out2"
fi

# Pull 0.1.0 from OCI into clean directory
PULL_DIR="$TEST_DIR/pulled"
mkdir -p "$PULL_DIR"

if pull_out=$(helm pull "oci://${TEST_REGISTRY}/charts/titanops-base" --version "0.1.0" --destination "$PULL_DIR" --plain-http 2>&1); then
  pass "Retrieved titanops-base-0.1.0 from OCI registry (DoD #2 satisfied)"
else
  fail "Retrieved titanops-base-0.1.0 from OCI registry" "$pull_out"
fi

# Verify pulled file matches original package SHA
ORIG_SHA=$(cat "$DIST_DIR/titanops-base-0.1.0.tgz.sha256" | awk '{print $1}')
if command -v shasum >/dev/null 2>&1; then
  PULLED_SHA=$(shasum -a 256 "$PULL_DIR/titanops-base-0.1.0.tgz" | awk '{print $1}')
else
  PULLED_SHA=$(sha256sum "$PULL_DIR/titanops-base-0.1.0.tgz" | awk '{print $1}')
fi

if [[ "$ORIG_SHA" == "$PULLED_SHA" ]]; then
  pass "Pulled archive checksum strictly matches original package digest ($ORIG_SHA)"
else
  fail "Pulled archive checksum matches original digest" "Orig: $ORIG_SHA, Pulled: $PULLED_SHA"
fi

# ----------------------------------------------------------------------------
# Test Suite 6: Remote OCI Chart Inspection (Zero Local Files)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 6: Remote OCI Chart Inspection (Zero Local Files)]${NC}"

CHART_INSPECT=$(helm show chart "oci://${TEST_REGISTRY}/charts/titanops-base" --version "0.1.0" --plain-http 2>&1)
if echo "$CHART_INSPECT" | grep -q "name: titanops-base" && echo "$CHART_INSPECT" | grep -q "version: 0.1.0"; then
  pass "helm show chart directly from OCI inspects remote metadata successfully"
else
  fail "helm show chart directly from OCI" "$CHART_INSPECT"
fi

VALUES_INSPECT=$(helm show values "oci://${TEST_REGISTRY}/charts/titanops-base" --version "0.1.0" --plain-http 2>&1)
if echo "$VALUES_INSPECT" | grep -q "replicaCount:"; then
  pass "helm show values directly from OCI inspects default values successfully"
else
  fail "helm show values directly from OCI" "$VALUES_INSPECT"
fi

# ----------------------------------------------------------------------------
# Test Suite 7: Direct helm install from Published OCI Chart (DoD Criterion #3)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 7: Direct helm install from Published OCI Chart (DoD #3)]${NC}"

# Test base install dry-run directly from oci://
if dry_base=$(helm install test-release "oci://${TEST_REGISTRY}/charts/titanops-base" --version "0.1.0" --dry-run --plain-http 2>&1); then
  pass "helm install --dry-run directly from published OCI chart succeeds (DoD #3 satisfied)"
else
  fail "helm install --dry-run directly from published OCI chart succeeds" "$dry_base"
fi

# Verify rendered manifest contains Kubernetes Deployment
if echo "$dry_base" | grep -q "kind: Deployment" && echo "$dry_base" | grep -q "kind: Service"; then
  pass "Published OCI chart renders valid Kubernetes Deployment & Service manifests"
else
  fail "Published OCI chart renders valid manifests"
fi

# Test multi-service layered install directly from oci:// with service values
if dry_svc=$(helm install appointment-service "oci://${TEST_REGISTRY}/charts/titanops-base" \
  --version "0.1.0" \
  --values "$REPO_ROOT/helm/values/appointment-service.yaml" \
  --dry-run \
  --plain-http 2>&1); then
  pass "helm install with microservice values layering directly from published OCI chart succeeds"
else
  fail "helm install with microservice values layering from published OCI chart" "$dry_svc"
fi

# Verify service values were applied
if echo "$dry_svc" | grep -q "appointment-service"; then
  pass "Layered values applied to published OCI chart (appointment-service contract active)"
else
  fail "Layered values applied to published OCI chart"
fi

# ----------------------------------------------------------------------------
# Test Suite 8: S3 Chart Repository Indexing (Alternative Repository Target)
# ----------------------------------------------------------------------------
echo -e "\n${BOLD}[Test Suite 8: S3 Chart Repository Indexing (Alternative Target)]${NC}"

S3_STAGING="$TEST_DIR/s3-staging"
mkdir -p "$S3_STAGING"
cp "$DIST_DIR"/*.tgz "$S3_STAGING/"

if index_out=$(helm repo index "$S3_STAGING" --url "s3://titanops-helm-charts/charts" 2>&1); then
  pass "helm repo index generated repository index for S3 bucket"
else
  fail "helm repo index generated repository index for S3 bucket" "$index_out"
fi

if [[ -f "$S3_STAGING/index.yaml" ]]; then
  pass "index.yaml generated"
else
  fail "index.yaml generated"
fi

INDEX_CONTENT=$(cat "$S3_STAGING/index.yaml")
if echo "$INDEX_CONTENT" | grep -q "name: titanops-base" && \
   echo "$INDEX_CONTENT" | grep -q "version: 0.1.0" && \
   echo "$INDEX_CONTENT" | grep -q "version: 0.1.1" && \
   echo "$INDEX_CONTENT" | grep -q "version: 1.0.0"; then
  pass "index.yaml contains all semantic versions (0.1.0, 0.1.1, 1.0.0)"
else
  fail "index.yaml contains all semantic versions"
fi

if echo "$INDEX_CONTENT" | grep -q "s3://titanops-helm-charts/charts/titanops-base-"; then
  pass "index.yaml points to canonical S3 artifact URIs"
else
  fail "index.yaml points to canonical S3 artifact URIs"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
echo -e "\n${CYAN}======================================================================${NC}"
echo -e " Verification Complete: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo -e "${CYAN}======================================================================${NC}"

[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
