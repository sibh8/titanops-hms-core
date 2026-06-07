#!/usr/bin/env bash
# run-tests.sh — Run MediCore integration tests
#
# Usage:
#   ./run-tests.sh                  # all tests
#   ./run-tests.sh health           # health checks only
#   ./run-tests.sh cross            # cross-service workflow only
#   ./run-tests.sh users providers  # specific suites
#
# Environment overrides (optional):
#   PATIENT_URL=http://localhost:8081 ./run-tests.sh
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Node version check ────────────────────────────────────────────────────────
NODE_VER=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
if [ -z "$NODE_VER" ] || [ "$NODE_VER" -lt 18 ]; then
  echo "ERROR: Node.js 18 or higher is required. Found: $(node --version 2>/dev/null || echo 'not installed')"
  exit 1
fi

# ── Wait for services (optional) ──────────────────────────────────────────────
wait_for() {
  local url="$1/actuator/health"
  local name="$2"
  local attempts=0
  echo -n "  Waiting for $name ..."
  while ! curl -sf "$url" > /dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ $attempts -ge 24 ]; then
      echo " TIMEOUT"
      echo "  ERROR: $name did not become healthy at $url within 2 minutes."
      return 1
    fi
    sleep 5
    echo -n "."
  done
  echo " UP"
}

if [ "${WAIT_FOR_SERVICES:-false}" = "true" ]; then
  echo "Waiting for all services to become healthy..."
  wait_for "${PATIENT_URL:-http://localhost:8081}"      "patient-service"
  wait_for "${APPOINTMENT_URL:-http://localhost:8082}"  "appointment-service"
  wait_for "${USER_URL:-http://localhost:8083}"         "user-service"
  wait_for "${BILLING_URL:-http://localhost:8084}"      "billing-service"
  wait_for "${ENCOUNTER_URL:-http://localhost:8085}"    "encounter-service"
  wait_for "${LAB_URL:-http://localhost:8086}"          "lab-service"
  wait_for "${MEDICATION_URL:-http://localhost:8087}"   "medication-service"
  wait_for "${PRESCRIPTION_URL:-http://localhost:8088}" "prescription-service"
  wait_for "${PROVIDER_URL:-http://localhost:8089}"     "provider-service"
  echo ""
fi

# ── Build file list ───────────────────────────────────────────────────────────
SUITE_MAP=(
  "health:00-health.test.js"
  "users:01-users.test.js"
  "providers:02-providers.test.js"
  "patients:03-patients.test.js"
  "appointments:04-appointments.test.js"
  "encounters:05-encounters.test.js"
  "lab:06-lab.test.js"
  "medications:07-medications.test.js"
  "prescriptions:08-prescriptions.test.js"
  "billing:09-billing.test.js"
  "cross:10-cross-service.test.js"
)

FILES=()
if [ $# -eq 0 ]; then
  for entry in "${SUITE_MAP[@]}"; do
    FILES+=("$DIR/tests/${entry#*:}")
  done
else
  for suite in "$@"; do
    found=false
    for entry in "${SUITE_MAP[@]}"; do
      if [ "${entry%%:*}" = "$suite" ]; then
        FILES+=("$DIR/tests/${entry#*:}")
        found=true
        break
      fi
    done
    if [ "$found" = "false" ]; then
      echo "ERROR: Unknown suite '$suite'. Valid: health users providers patients appointments encounters lab medications prescriptions billing cross"
      exit 1
    fi
  done
fi

echo "=================================================="
echo " MediCore Integration Tests"
echo "=================================================="
echo "Running ${#FILES[@]} suite(s)..."
echo ""

node --test --test-reporter=spec "${FILES[@]}"
