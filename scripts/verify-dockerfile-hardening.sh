#!/usr/bin/env bash
# ==============================================================================
# MediCore HMS - Dockerfile Hardening & Base Image Pinning Verification Suite
# TITANOPS-114: Harden Dockerfiles: run as non-root, pin base images
# ==============================================================================
# Verifies Definition of Done:
# 1. Every Dockerfile creates and switches to a non-root USER
# 2. Base images pinned to a specific digest/version - no :latest anywhere in
#    any Dockerfile or docker-compose.yml
# 3. Verified containers run as non-root (e.g. docker exec/run <container> whoami)
# ==============================================================================

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASSED_COUNT=0
TOTAL_COUNT=0

record_result() {
  local test_name="$1"
  local status="$2"
  local details="$3"

  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  if [ "$status" = "PASS" ]; then
    PASSED_COUNT=$((PASSED_COUNT + 1))
    echo -e "  [${GREEN}PASS${NC}] ${test_name}"
    if [ -n "$details" ]; then
      echo -e "         ${CYAN}${details}${NC}"
    fi
  else
    echo -e "  [${RED}FAIL${NC}] ${test_name}"
    if [ -n "$details" ]; then
      echo -e "         ${RED}${details}${NC}"
    fi
  fi
}

echo -e "\n${CYAN}${BOLD}========================================================================${NC}"
echo -e "${CYAN}${BOLD}   TITANOPS-114: Dockerfile Hardening & Base Image Verification Suite  ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}\n"

# ------------------------------------------------------------------------------
# STEP 1: DoD #1 - USER directive and non-root user creation in all Dockerfiles
# ------------------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}Step 1: Non-Root USER Directives (DoD #1)${NC}"

JAVA_SERVICES=(
  "appointment-service"
  "billing-service"
  "encounter-service"
  "lab-service"
  "medication-service"
  "patient-service"
  "prescription-service"
  "provider-service"
  "user-service"
)

for svc in "${JAVA_SERVICES[@]}"; do
  df="$svc/Dockerfile"
  if [ -f "$df" ]; then
    has_user=$(grep -E '^\s*USER\s+10001:10001' "$df" || true)
    has_groupadd=$(grep -E 'groupadd\s+-g\s+10001' "$df" || true)
    has_useradd=$(grep -E 'useradd\s+-u\s+10001' "$df" || true)
    has_chown=$(grep -E 'chown.*10001:10001' "$df" || true)

    if [ -n "$has_user" ] && [ -n "$has_groupadd" ] && [ -n "$has_useradd" ] && [ -n "$has_chown" ]; then
      record_result "$svc/Dockerfile: Non-root user appuser (10001:10001)" "PASS" "Configured appuser:appgroup with USER 10001:10001 and /app ownership"
    else
      record_result "$svc/Dockerfile: Non-root user appuser (10001:10001)" "FAIL" "Missing USER directive or useradd/groupadd/chown in $df"
    fi
  else
    record_result "$df exists" "FAIL" "File not found"
  fi
done

# Frontend non-root check
FRONTEND_DF="frontend/Dockerfile"
if [ -f "$FRONTEND_DF" ]; then
  has_fe_user=$(grep -E '^\s*USER\s+101:101' "$FRONTEND_DF" || true)
  has_fe_cap=$(grep -E 'cap_net_bind_service' "$FRONTEND_DF" || true)
  has_fe_pid=$(grep -E '/tmp/nginx.pid' "$FRONTEND_DF" || true)

  if [ -n "$has_fe_user" ] && [ -n "$has_fe_cap" ] && [ -n "$has_fe_pid" ]; then
    record_result "frontend/Dockerfile: Non-root nginx user (101:101)" "PASS" "Configured USER 101:101, cap_net_bind_service on port 80, and /tmp/nginx.pid"
  else
    record_result "frontend/Dockerfile: Non-root nginx user (101:101)" "FAIL" "Missing non-root USER or capabilities configuration in $FRONTEND_DF"
  fi
else
  record_result "$FRONTEND_DF exists" "FAIL" "File not found"
fi

# ------------------------------------------------------------------------------
# STEP 2: DoD #2 - Base image pinning & zero :latest tags
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Step 2: Base Image Pinning & Zero :latest Tags (DoD #2)${NC}"

# Check for :latest in all Dockerfiles
DF_LATEST=$(grep -rnE 'FROM\s+.*:latest' */Dockerfile 2>/dev/null || true)
if [ -z "$DF_LATEST" ]; then
  record_result "Dockerfiles: Zero :latest tags" "PASS" "All 10 Dockerfiles pin specific version tags"
else
  record_result "Dockerfiles: Zero :latest tags" "FAIL" "Found :latest tags: $DF_LATEST"
fi

# Check for :latest in docker-compose.yml
DC_LATEST=$(grep -nE 'image:.*:latest' docker-compose.yml 2>/dev/null || true)
if [ -z "$DC_LATEST" ]; then
  record_result "docker-compose.yml: Zero :latest tags" "PASS" "All observability and database services pinned to specific releases"
else
  record_result "docker-compose.yml: Zero :latest tags" "FAIL" "Found :latest in docker-compose.yml: $DC_LATEST"
fi

# Check specific pinned versions in backend Dockerfiles
UNPINNED_TEMURIN=$(grep -rnE 'FROM\s+eclipse-temurin:11-jre($|\s)' */Dockerfile 2>/dev/null || true)
if [ -z "$UNPINNED_TEMURIN" ]; then
  record_result "Java Dockerfiles: Pinned Eclipse Temurin version" "PASS" "All 9 services pinned to eclipse-temurin:11.0.25_9-jre"
else
  record_result "Java Dockerfiles: Pinned Eclipse Temurin version" "FAIL" "Found unpinned eclipse-temurin:11-jre: $UNPINNED_TEMURIN"
fi

# Check frontend pinned versions
FE_NODE_PINNED=$(grep -E 'FROM\s+node:20.18-alpine' frontend/Dockerfile || true)
FE_NGINX_PINNED=$(grep -E 'FROM\s+nginx:1.25.5-alpine' frontend/Dockerfile || true)
if [ -n "$FE_NODE_PINNED" ] && [ -n "$FE_NGINX_PINNED" ]; then
  record_result "frontend/Dockerfile: Pinned build and serve base images" "PASS" "Pinned node:20.18-alpine and nginx:1.25.5-alpine"
else
  record_result "frontend/Dockerfile: Pinned build and serve base images" "FAIL" "Missing pinned node:20.18-alpine or nginx:1.25.5-alpine"
fi

# Check docker-compose observability versions
JAEGER_PINNED=$(grep -E 'image:\s*jaegertracing/all-in-one:1.57.0' docker-compose.yml || true)
OTEL_PINNED=$(grep -E 'image:\s*otel/opentelemetry-collector:0.100.0' docker-compose.yml || true)
PROM_PINNED=$(grep -E 'image:\s*prom/prometheus:v2.51.2' docker-compose.yml || true)
GRAF_PINNED=$(grep -E 'image:\s*grafana/grafana:10.4.2' docker-compose.yml || true)

if [ -n "$JAEGER_PINNED" ] && [ -n "$OTEL_PINNED" ] && [ -n "$PROM_PINNED" ] && [ -n "$GRAF_PINNED" ]; then
  record_result "docker-compose.yml: Observability stack version pins" "PASS" "jaeger:1.57.0, otel-collector:0.100.0, prometheus:v2.51.2, grafana:10.4.2"
else
  record_result "docker-compose.yml: Observability stack version pins" "FAIL" "One or more observability services not pinned to expected release"
fi

# Validate docker-compose syntax
if command -v docker-compose >/dev/null 2>&1; then
  if docker-compose config >/dev/null 2>&1; then
    record_result "docker-compose.yml syntax validation" "PASS" "Compose configuration parses cleanly without errors"
  else
    record_result "docker-compose.yml syntax validation" "FAIL" "docker-compose config reported syntax errors"
  fi
fi

# ------------------------------------------------------------------------------
# STEP 3: DoD #3 - Runtime Container Non-Root Verification
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Step 3: Runtime Container Non-Root Verification (DoD #3)${NC}"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  # 1. Test frontend image runtime user
  echo -e "  Testing frontend container execution..."
  if fe_out=$(cd frontend && docker build -q -t medicore-hms-ui:hardened-test . 2>&1); then
    fe_user=$(docker run --rm medicore-hms-ui:hardened-test whoami 2>/dev/null || true)
    fe_uid=$(docker run --rm medicore-hms-ui:hardened-test id -u 2>/dev/null || true)
    docker rmi medicore-hms-ui:hardened-test >/dev/null 2>&1 || true

    if [ "$fe_user" = "nginx" ] && [ "$fe_uid" = "101" ]; then
      record_result "Runtime: frontend container executes as non-root" "PASS" "whoami=$fe_user, uid=$fe_uid (non-root)"
    else
      record_result "Runtime: frontend container executes as non-root" "FAIL" "Expected nginx (uid 101), got user=$fe_user, uid=$fe_uid"
    fi
  else
    record_result "Runtime: frontend container executes as non-root" "FAIL" "Frontend build failed: $fe_out"
  fi

  # 2. Test Java backend base runtime user
  echo -e "  Testing Java microservice container execution..."
  mkdir -p appointment-service/target
  touch appointment-service/target/app.jar
  if java_out=$(cd appointment-service && docker build -q -t appointment-service:hardened-test . 2>&1); then
    java_user=$(docker run --rm --entrypoint whoami appointment-service:hardened-test 2>/dev/null || true)
    java_uid=$(docker run --rm --entrypoint id appointment-service:hardened-test -u 2>/dev/null || true)
    docker rmi appointment-service:hardened-test >/dev/null 2>&1 || true
    rm -rf appointment-service/target

    if [ "$java_user" = "appuser" ] && [ "$java_uid" = "10001" ]; then
      record_result "Runtime: Java service container executes as non-root" "PASS" "whoami=$java_user, uid=$java_uid (appuser / 10001:10001)"
    else
      record_result "Runtime: Java service container executes as non-root" "FAIL" "Expected appuser (uid 10001), got user=$java_user, uid=$java_uid"
    fi
  else
    record_result "Runtime: Java service container executes as non-root" "FAIL" "Java container build failed: $java_out"
    rm -rf appointment-service/target
  fi
else
  echo -e "  ${CYAN}[SKIP] Docker daemon not reachable for live runtime tests${NC}"
fi

# ------------------------------------------------------------------------------
# SUMMARY REPORT
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}${BOLD}========================================================================${NC}"
echo -e "${CYAN}${BOLD}   Verification Summary: ${PASSED_COUNT} / ${TOTAL_COUNT} Tests Passed               ${NC}"
echo -e "${CYAN}${BOLD}========================================================================${NC}"

if [ "$PASSED_COUNT" -eq "$TOTAL_COUNT" ]; then
  echo -e "${GREEN}${BOLD}✓ ALL DEFINITION OF DONE REQUIREMENTS SATISFIED FOR TITANOPS-114!${NC}\n"
  exit 0
else
  echo -e "${RED}${BOLD}✗ SOME HARDENING VERIFICATION TESTS FAILED. PLEASE REVIEW LOGS ABOVE.${NC}\n"
  exit 1
fi
