#!/bin/bash

# MediCore HMS — Sandbox Setup Script
# Starts MySQL, observability stack, and all 9 microservices via Docker Compose.
# Every variable can be pre-set as an environment variable to skip the prompt,
# or left unset to be prompted interactively.
#
# Usage:
#   ./setup-sandbox.sh
#
# Skip prompts by pre-exporting variables:
#   export SPRING_DATASOURCE_PASSWORD=secret
#   export PATIENT_SERVICE_PORT=9081
#   ./setup-sandbox.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.sandbox.env"

# ─── Load saved config from previous run ──────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
  echo "Loading saved configuration from .sandbox.env (delete it to re-prompt)"
  # shellcheck source=/dev/null
  set -a; source "$ENV_FILE"; set +a
fi

# ─── Helper: prompt for a value if not already set in the environment ─────────
prompt_if_unset() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="$3"
  local is_secret="${4:-false}"

  if [ -z "${!var_name}" ]; then
    if [ "$is_secret" = "true" ]; then
      read -s -p "$prompt_text [default: $default_value]: " input; echo
    else
      read -p "$prompt_text [default: $default_value]: " input
    fi
    export "$var_name"="${input:-$default_value}"
  else
    echo "  $var_name already set via environment."
  fi
}

# ─── Database ─────────────────────────────────────────────────────────────────
echo "=============================================="
echo " MediCore HMS Sandbox — Configuration"
echo "=============================================="
echo "Press ENTER to accept the default value shown."
echo ""
echo "--- Database ---"

prompt_if_unset "MYSQL_DATABASE"             "MySQL database name"         "medicore_hms"
prompt_if_unset "SPRING_DATASOURCE_USERNAME" "MySQL application user"      "medicore"
prompt_if_unset "SPRING_DATASOURCE_PASSWORD" "MySQL application password"  "medicore_pass"  "true"
prompt_if_unset "MYSQL_ROOT_PASSWORD"        "MySQL root password"         "root_pass"      "true"
prompt_if_unset "MYSQL_PORT"                 "MySQL host port"             "3306"

# ─── Service Ports ────────────────────────────────────────────────────────────
echo ""
echo "--- Microservice Ports ---"

prompt_if_unset "PATIENT_SERVICE_PORT"      "Patient Service port"      "8081"
prompt_if_unset "APPOINTMENT_SERVICE_PORT" "Appointment Service port"  "8082"
prompt_if_unset "USER_SERVICE_PORT"        "User Service port"         "8083"
prompt_if_unset "BILLING_SERVICE_PORT"     "Billing Service port"      "8084"
prompt_if_unset "ENCOUNTER_SERVICE_PORT"   "Encounter Service port"    "8085"
prompt_if_unset "LAB_SERVICE_PORT"         "Lab Service port"          "8086"
prompt_if_unset "MEDICATION_SERVICE_PORT"  "Medication Service port"   "8087"
prompt_if_unset "PRESCRIPTION_SERVICE_PORT" "Prescription Service port" "8088"
prompt_if_unset "PROVIDER_SERVICE_PORT"    "Provider Service port"     "8089"

# ─── Observability Ports ──────────────────────────────────────────────────────
echo ""
echo "--- Observability Ports ---"

prompt_if_unset "FRONTEND_PORT"    "Frontend (UI) port"    "3000"
prompt_if_unset "GRAFANA_PORT"     "Grafana port"          "3001"
prompt_if_unset "PROMETHEUS_PORT"  "Prometheus port"       "9090"
prompt_if_unset "JAEGER_UI_PORT"   "Jaeger UI port"        "16686"

# ─── Observability Credentials ────────────────────────────────────────────────
echo ""
echo "--- Observability Credentials ---"

prompt_if_unset "GRAFANA_ADMIN_PASSWORD" "Grafana admin password" "admin" "true"

# ─── OTEL Settings ────────────────────────────────────────────────────────────
echo ""
echo "--- OpenTelemetry Settings ---"

prompt_if_unset "OTEL_EXPORTER_OTLP_ENDPOINT" "OTLP collector endpoint"   "http://otel-collector:4317"
prompt_if_unset "OTEL_TRACES_EXPORTER"         "Traces exporter (otlp/jaeger/none)"  "otlp"
prompt_if_unset "OTEL_METRICS_EXPORTER"        "Metrics exporter (otlp/prometheus/none)" "otlp"
prompt_if_unset "OTEL_LOGS_EXPORTER"           "Logs exporter (otlp/none)"  "otlp"

echo ""
echo "All configuration confirmed. Starting services..."
echo ""

# ─── Persist config for next run ──────────────────────────────────────────────
cat > "$ENV_FILE" <<EOF
MYSQL_DATABASE=${MYSQL_DATABASE}
SPRING_DATASOURCE_USERNAME=${SPRING_DATASOURCE_USERNAME}
SPRING_DATASOURCE_PASSWORD=${SPRING_DATASOURCE_PASSWORD}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_PORT=${MYSQL_PORT}
PATIENT_SERVICE_PORT=${PATIENT_SERVICE_PORT}
APPOINTMENT_SERVICE_PORT=${APPOINTMENT_SERVICE_PORT}
USER_SERVICE_PORT=${USER_SERVICE_PORT}
BILLING_SERVICE_PORT=${BILLING_SERVICE_PORT}
ENCOUNTER_SERVICE_PORT=${ENCOUNTER_SERVICE_PORT}
LAB_SERVICE_PORT=${LAB_SERVICE_PORT}
MEDICATION_SERVICE_PORT=${MEDICATION_SERVICE_PORT}
PRESCRIPTION_SERVICE_PORT=${PRESCRIPTION_SERVICE_PORT}
PROVIDER_SERVICE_PORT=${PROVIDER_SERVICE_PORT}
FRONTEND_PORT=${FRONTEND_PORT}
GRAFANA_PORT=${GRAFANA_PORT}
PROMETHEUS_PORT=${PROMETHEUS_PORT}
JAEGER_UI_PORT=${JAEGER_UI_PORT}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT}
OTEL_TRACES_EXPORTER=${OTEL_TRACES_EXPORTER}
OTEL_METRICS_EXPORTER=${OTEL_METRICS_EXPORTER}
OTEL_LOGS_EXPORTER=${OTEL_LOGS_EXPORTER}
EOF
echo "Configuration saved to .sandbox.env"

# ─── MySQL ────────────────────────────────────────────────────────────────────
echo "Starting MySQL..."
docker-compose up -d mysql

echo "Waiting for MySQL to be ready..."
until docker-compose exec -T mysql \
    mysqladmin ping -h localhost \
    -u "$SPRING_DATASOURCE_USERNAME" \
    -p"$SPRING_DATASOURCE_PASSWORD" \
    --silent 2>/dev/null; do
  echo "  MySQL not ready yet — retrying in 5s..."
  sleep 5
done
echo "MySQL is ready."
echo ""

# ─── Observability ────────────────────────────────────────────────────────────
echo "Starting observability stack..."
docker-compose up -d jaeger otel-collector prometheus grafana
echo ""

# ─── Microservices ────────────────────────────────────────────────────────────
echo "Building and starting microservices..."
# Only pass --build when service images do not exist yet
if docker images --format '{{.Repository}}' | grep -q 'java-microservices-patient-service'; then
  BUILD_FLAG=""
  echo "  (Images found — skipping rebuild. Delete images to force a fresh build.)"
else
  BUILD_FLAG="--build"
  echo "  (No images found — building from source...)"
fi
# shellcheck disable=SC2086
docker-compose up -d $BUILD_FLAG \
  patient-service \
  appointment-service \
  user-service \
  billing-service \
  encounter-service \
  lab-service \
  medication-service \
  prescription-service \
  provider-service

# ─── Frontend ─────────────────────────────────────────────────────────────────
echo ""
echo "Building and starting frontend..."
if docker images --format '{{.Repository}}' | grep -q 'java-microservices-medicore-hms-ui'; then
  FRONTEND_BUILD_FLAG=""
else
  FRONTEND_BUILD_FLAG="--build"
fi
# shellcheck disable=SC2086
docker-compose up -d $FRONTEND_BUILD_FLAG medicore-hms-ui

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo " MediCore HMS Sandbox is up and running"
echo "=============================================="
echo ""
echo "=== Database ==="
echo "  Host:     localhost:$MYSQL_PORT"
echo "  Database: $MYSQL_DATABASE"
echo "  User:     $SPRING_DATASOURCE_USERNAME"
echo "  Password: (as entered)"
echo ""
echo "=== Frontend ==="
echo "  MediCore HMS UI:      http://localhost:$FRONTEND_PORT"
echo ""
echo "=== Observability ==="
echo "  Jaeger UI:            http://localhost:$JAEGER_UI_PORT  (distributed tracing)"
echo "  Grafana:              http://localhost:$GRAFANA_PORT   (admin / as entered)"
echo "  Prometheus:           http://localhost:$PROMETHEUS_PORT"
echo ""
echo "=== OTEL ==="
echo "  Collector endpoint:   $OTEL_EXPORTER_OTLP_ENDPOINT"
echo "  Traces exporter:      $OTEL_TRACES_EXPORTER"
echo "  Metrics exporter:     $OTEL_METRICS_EXPORTER"
echo "  Logs exporter:        $OTEL_LOGS_EXPORTER"
echo ""
echo "=== Microservices ==="
echo "  Patient Service:      http://localhost:$PATIENT_SERVICE_PORT/api/patients"
echo "  Appointment Service:  http://localhost:$APPOINTMENT_SERVICE_PORT/api/appointments"
echo "  User Service:         http://localhost:$USER_SERVICE_PORT/api/users"
echo "  Billing Service:      http://localhost:$BILLING_SERVICE_PORT/api/invoices"
echo "  Encounter Service:    http://localhost:$ENCOUNTER_SERVICE_PORT/api/encounters"
echo "  Lab Service:          http://localhost:$LAB_SERVICE_PORT/api/labs/orders"
echo "  Medication Service:   http://localhost:$MEDICATION_SERVICE_PORT/api/medications"
echo "  Prescription Service: http://localhost:$PRESCRIPTION_SERVICE_PORT/api/prescriptions"
echo "  Provider Service:     http://localhost:$PROVIDER_SERVICE_PORT/api/providers"
