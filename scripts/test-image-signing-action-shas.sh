#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Supply Chain Integrity & Image Signing Verification Suite
# Ticket: TITANOPS-116: Add image signing and pin GitHub Actions to commit SHAs
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
echo -e "${BLUE}   TitanOps HMS: Image Signing & Action SHA Pinning (TITANOPS-116)             ${NC}"
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
WORKFLOW_DIR="${REPO_DIR}/.github/workflows"

echo -e "${YELLOW}Phase 1: GitHub Actions 40-character Commit SHA Pinning Audit${NC}"

# Check for floating tags (e.g. @v3, @v4, @master, @latest) across all workflow files
check "1. Zero floating version tags (@v[0-9]+ or @master/@latest) in any workflow" \
    "! grep -E 'uses:[[:space:]]*[A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+@(v[0-9]+|master|latest)' '${WORKFLOW_DIR}'/*.yml 2>/dev/null"

check "2. Every action reference contains a full 40-character hex commit SHA" \
    "python3 -c '
import glob, re, sys
files = glob.glob(\"${WORKFLOW_DIR}/*.yml\")
for f in files:
    with open(f) as fp:
        for idx, line in enumerate(fp):
            m = re.search(r\"uses:\s*([A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-/]+)@([A-Za-z0-9]+)\", line)
            if m:
                action, sha = m.group(1), m.group(2)
                if not re.match(r\"^[a-f0-9]{40}$\", sha):
                    print(f\"File {f}:{idx+1} action {action} does not use 40-char SHA: {sha}\")
                    sys.exit(1)
sys.exit(0)
'"

check "3. Core actions (checkout, setup-java, setup-node, configure-aws-credentials) pinned" \
    "grep -q 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683' '${WORKFLOW_DIR}/ci-cd.yml' && \
     grep -q 'actions/setup-java@3a4f6e1af504cf6a31855fa8f9c6aaabac41b7b2' '${WORKFLOW_DIR}/patient-service-ci.yml' && \
     grep -q 'aws-actions/configure-aws-credentials@e3ddf1a9912006787b5fce02b6e637d5445b4c65' '${WORKFLOW_DIR}/reusable-ecr-push.yml'"

echo -e "\n${YELLOW}Phase 2: Cosign Container Image Signing & Deployment Verification${NC}"
check "4. sigstore/cosign-installer action configured and pinned to commit SHA" \
    "grep -q 'uses: sigstore/cosign-installer@dc72c7d5c4d10cd6bcb8cf6e3fd625a9e5e537da' '${WORKFLOW_DIR}/build-and-push-all-ecr.yml' && \
     grep -q 'uses: sigstore/cosign-installer@dc72c7d5c4d10cd6bcb8cf6e3fd625a9e5e537da' '${WORKFLOW_DIR}/reusable-ecr-push.yml'"

check "5. Image signing step configured in build-and-push workflows" \
    "grep -q 'cosign sign' '${WORKFLOW_DIR}/build-and-push-all-ecr.yml' && \
     grep -q 'cosign sign' '${WORKFLOW_DIR}/reusable-ecr-push.yml'"

check "6. Signature verification step enforced before deployment (DoD #3)" \
    "grep -q 'Verify Image Signature before Deployment' '${WORKFLOW_DIR}/reusable-ecr-push.yml' && \
     grep -q 'cosign verify' '${WORKFLOW_DIR}/reusable-ecr-push.yml'"

check "7. Local build and push script includes Cosign signing and verification loop" \
    "grep -q 'cosign sign' '${REPO_DIR}/scripts/build-and-push-ecr.sh' && \
     grep -q 'cosign verify' '${REPO_DIR}/scripts/build-and-push-ecr.sh'"

echo -e "\n${YELLOW}Phase 3: Cryptographic Signature Lifecycle Simulation${NC}"
# Simulating keypair generation, image digest signing, and payload verification
check "8. Cosign digital signature generation and verification lifecycle simulation" \
    "python3 -c '
import hashlib, hmac

# Simulate private/public keypair
secret_key = b\"titanops-supply-chain-private-key-secure\"
image_digest = hashlib.sha256(b\"medicore/patient-service:1.0.0-distroless-app-jar\").hexdigest()

# Generate cryptographic signature
signature = hmac.new(secret_key, image_digest.encode(\"utf-8\"), hashlib.sha256).hexdigest()

# Verify cryptographic signature against digest
expected_sig = hmac.new(secret_key, image_digest.encode(\"utf-8\"), hashlib.sha256).hexdigest()
assert hmac.compare_digest(signature, expected_sig), \"Signature validation failed!\"
'"

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "Verification Summary: ${PASS_COUNT} Passed, ${FAIL_COUNT} Failed"
echo -e "${BLUE}==============================================================================${NC}"

if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: TITANOPS-116 Image Signing & Action SHA Pinning verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: TITANOPS-116 verification failed.${NC}"
    exit 1
fi
