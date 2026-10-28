#!/usr/bin/env bash
# ============================================================================
# TITANOPS-52: Package and Publish Helm Chart
#
# Packages the base Helm chart (helm/titanops-base) with semantic versioning
# and publishes it to a target repository (AWS ECR via OCI, or S3-backed repo).
#
# Definition of Done:
#   1. Chart is packaged with a semantic version (SemVer 2.0.0)
#   2. Chart is pushed to and retrievable from repository (OCI/ECR or S3)
#   3. helm install from the published chart (not local files) succeeds
#
# Usage:
#   ./helm/publish-chart.sh [options]
#
# Options:
#   --version <semver>       Chart semantic version (e.g. 0.1.0, 1.0.0). Defaults to Chart.yaml.
#   --app-version <version>  Application version. Defaults to Chart.yaml.
#   --target <oci|s3|local>  Target repository type (default: oci).
#   --registry <host/bucket> OCI registry host or S3 bucket (e.g. 111122223333.dkr.ecr.ap-south-1.amazonaws.com).
#   --repo <repo-name>       Repository/path on registry (default: titanops-base).
#   --region <aws-region>    AWS region (default: ap-south-1).
#   --output-dir <path>      Output directory for packaged .tgz (default: dist/helm).
#   --plain-http             Allow plain HTTP for OCI push (for local/testing registries).
#   --skip-login             Skip automated docker/helm registry login (if already logged in).
#   --verify                 Verify retrieval and test dry-run install from remote repository.
#   --help, -h               Show this help message.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="helm/titanops-base"
if [[ ! -d "$CHART_DIR" && -d "$SCRIPT_DIR/titanops-base" ]]; then
  CHART_DIR="$SCRIPT_DIR/titanops-base"
fi
CHART_NAME="titanops-base"
DEFAULT_OUTPUT_DIR="dist/helm"

TARGET="oci"
REGISTRY=""
REPO_NAME="titanops-base"
AWS_REGION="${AWS_REGION:-ap-south-1}"
VERSION=""
APP_VERSION=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
PLAIN_HTTP=false
SKIP_LOGIN=false
VERIFY=false

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
fatal() { error "$*"; exit 1; }

usage() {
  sed -n '2,/^# ============================================================================/p' "$0" | sed 's/^# \?//'
  exit 0
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --app-version) APP_VERSION="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --repo) REPO_NAME="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --plain-http) PLAIN_HTTP=true; shift 1 ;;
    --skip-login) SKIP_LOGIN=true; shift 1 ;;
    --verify) VERIFY=true; shift 1 ;;
    -h|--help) usage ;;
    *) fatal "Unknown parameter: $1. Run with --help for usage." ;;
  esac
done

# Step 0: Pre-flight tool check
command -v helm >/dev/null 2>&1 || fatal "Helm binary 'helm' not found on PATH."
[[ -f "$CHART_DIR/Chart.yaml" ]] || fatal "Chart file $CHART_DIR/Chart.yaml not found."

# Extract defaults from Chart.yaml if not provided
CURRENT_CHART_VER=$(awk -F': ' '/^version:/ {print $2}' "$CHART_DIR/Chart.yaml" | tr -d '"' | tr -d "'" | tr -d ' ')
CURRENT_APP_VER=$(awk -F': ' '/^appVersion:/ {print $2}' "$CHART_DIR/Chart.yaml" | tr -d '"' | tr -d "'" | tr -d ' ')

VERSION="${VERSION:-$CURRENT_CHART_VER}"
APP_VERSION="${APP_VERSION:-$CURRENT_APP_VER}"

# Step 1: Validate Semantic Versioning (SemVer 2.0.0)
SEMVER_REGEX="^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$"
if [[ ! "$VERSION" =~ $SEMVER_REGEX ]]; then
  fatal "Invalid semantic version: '$VERSION'. Must match SemVer 2.0.0 (e.g. 0.1.0, 1.2.3, 1.0.0-rc.1)."
fi

info "Chart: ${BOLD}${CHART_NAME}${NC}"
info "Semantic Version: ${BOLD}${VERSION}${NC}"
info "App Version: ${BOLD}${APP_VERSION}${NC}"
info "Target Type: ${BOLD}${TARGET}${NC}"
info "Output Directory: ${BOLD}${OUTPUT_DIR}${NC}"

# Step 2: Lint the chart
info "Running Helm lint on $CHART_DIR..."
helm lint "$CHART_DIR" || fatal "Helm lint failed."
success "Helm lint passed."

# Step 3: Package the chart with semantic versioning
mkdir -p "$OUTPUT_DIR"
info "Packaging chart with semantic version $VERSION..."
helm package "$CHART_DIR" \
  --version "$VERSION" \
  --app-version "$APP_VERSION" \
  --destination "$OUTPUT_DIR"

PACKAGE_FILE="${CHART_NAME}-${VERSION}.tgz"
PACKAGE_PATH="${OUTPUT_DIR}/${PACKAGE_FILE}"
[[ -f "$PACKAGE_PATH" ]] || fatal "Expected package archive $PACKAGE_PATH was not created."

# Step 4: Generate checksum
if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$PACKAGE_PATH" > "${PACKAGE_PATH}.sha256"
elif command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$PACKAGE_PATH" > "${PACKAGE_PATH}.sha256"
fi
SHA_VALUE=$(cat "${PACKAGE_PATH}.sha256" | awk '{print $1}')
success "Packaged chart: ${BOLD}${PACKAGE_PATH}${NC} (SHA256: ${SHA_VALUE})"

# Step 5: Publish based on target
if [[ "$TARGET" == "local" ]]; then
  success "Local package complete at $PACKAGE_PATH. Skipping remote publish."
  exit 0
fi

if [[ -z "$REGISTRY" ]]; then
  # If registry not specified, check environment or AWS CLI
  if [[ "$TARGET" == "oci" ]]; then
    if [[ -n "${AWS_ACCOUNT_ID:-}" ]]; then
      REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    elif command -v aws >/dev/null 2>&1; then
      ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
      if [[ -n "$ACCOUNT" ]]; then
        REGISTRY="${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
      fi
    fi
  fi
fi

if [[ -z "$REGISTRY" ]]; then
  warn "No registry specified via --registry and no default AWS account detected."
  warn "Chart has been packaged at: $PACKAGE_PATH"
  info "To publish manually to an OCI registry (e.g. AWS ECR):"
  echo "  helm push $PACKAGE_PATH oci://<registry-host>/${REPO_NAME}"
  info "To publish manually to S3:"
  echo "  aws s3 cp $PACKAGE_PATH s3://<bucket>/charts/"
  exit 0
fi

if [[ "$TARGET" == "oci" ]]; then
  # OCI Distribution (AWS ECR or OCI-compliant registry)
  OCI_REMOTE="oci://${REGISTRY}/${REPO_NAME}"
  info "Publishing OCI chart to ${BOLD}${OCI_REMOTE}${NC}..."

  # Login to AWS ECR if targeting amazonaws.com and not skipped
  if [[ "$SKIP_LOGIN" == "false" && "$REGISTRY" =~ \.amazonaws\.com$ ]]; then
    if command -v aws >/dev/null 2>&1; then
      info "Logging into AWS ECR ($REGISTRY) via AWS CLI..."
      aws ecr get-login-password --region "$AWS_REGION" | \
        helm registry login --username AWS --password-stdin "$REGISTRY"
    else
      warn "aws CLI not found; assuming caller already authenticated with helm registry login."
    fi
  fi

  EXTRA_FLAGS=()
  if [[ "$PLAIN_HTTP" == "true" ]]; then
    EXTRA_FLAGS+=("--plain-http")
  fi

  helm push "$PACKAGE_PATH" "$OCI_REMOTE" "${EXTRA_FLAGS[@]}"
  success "Successfully pushed Helm chart to ${BOLD}${OCI_REMOTE}:${VERSION}${NC}"

  if [[ "$VERIFY" == "true" ]]; then
    info "Verifying retrieval and installability from ${OCI_REMOTE}..."
    VERIFY_DIR=$(mktemp -d /tmp/helm-verify-XXXXXX)
    trap "rm -rf '$VERIFY_DIR'" EXIT

    PULL_TARGET="${OCI_REMOTE}"
    # If REPO_NAME does not include chart name, pull target includes chart name
    if [[ "$REPO_NAME" != *"$CHART_NAME"* ]]; then
      PULL_TARGET="${OCI_REMOTE}/${CHART_NAME}"
    fi

    info "Testing helm pull from $PULL_TARGET --version $VERSION..."
    helm pull "$PULL_TARGET" --version "$VERSION" --destination "$VERIFY_DIR" "${EXTRA_FLAGS[@]}"
    [[ -f "$VERIFY_DIR/$PACKAGE_FILE" ]] || fatal "Verification pull failed: archive not retrieved."
    success "Verification pull succeeded: $VERIFY_DIR/$PACKAGE_FILE"

    info "Testing helm install --dry-run directly from OCI repository..."
    helm install verify-test "$PULL_TARGET" \
      --version "$VERSION" \
      --dry-run \
      "${EXTRA_FLAGS[@]}" >/dev/null
    success "Verification install --dry-run directly from OCI chart succeeded (DoD #3 satisfied)."
  fi

elif [[ "$TARGET" == "s3" ]]; then
  # S3-backed Helm repository
  S3_BUCKET="${REGISTRY#s3://}"
  info "Publishing to S3 bucket s3://${S3_BUCKET}/charts/..."

  command -v aws >/dev/null 2>&1 || fatal "AWS CLI 'aws' required for S3 target."
  
  # Generate or update repository index
  info "Indexing chart repository in $OUTPUT_DIR..."
  helm repo index "$OUTPUT_DIR" --url "s3://${S3_BUCKET}/charts"

  # Sync chart archive and index to S3
  info "Uploading $PACKAGE_FILE to S3..."
  aws s3 cp "$PACKAGE_PATH" "s3://${S3_BUCKET}/charts/${PACKAGE_FILE}"
  aws s3 cp "${OUTPUT_DIR}/index.yaml" "s3://${S3_BUCKET}/charts/index.yaml"

  success "Successfully published chart to s3://${S3_BUCKET}/charts/${PACKAGE_FILE}"

  if [[ "$VERIFY" == "true" ]]; then
    info "Verifying S3 chart retrieval..."
    aws s3 ls "s3://${S3_BUCKET}/charts/${PACKAGE_FILE}"
    success "S3 verification succeeded."
  fi

else
  fatal "Unsupported target: '$TARGET'. Use 'oci', 's3', or 'local'."
fi

success "TITANOPS-52 Helm chart packaging & publishing complete!"
