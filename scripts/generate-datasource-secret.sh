#!/usr/bin/env bash
# ==============================================================================
# TitanOps HMS: Secure Kubernetes Secret Generator for RDS Datasource (TITANOPS-71)
# ==============================================================================
set -euo pipefail

NAMESPACE="${NAMESPACE:-hms}"
SECRET_NAME="${SECRET_NAME:-titanops-datasource-credentials}"
DB_HOST="${DB_HOST:-titanops-dev-mysql.cluster-xyz.us-east-1.rds.amazonaws.com}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-medicore_hms}"
DB_USER="${DB_USER:-medicore}"
DB_PASSWORD="${DB_PASSWORD:-}"

if [ -z "${DB_PASSWORD}" ]; then
    echo "ERROR: DB_PASSWORD environment variable must be provided." >&2
    exit 1
fi

JDBC_URL="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useSSL=true&requireSSL=true&verifyServerCertificate=true&allowPublicKeyRetrieval=true"

kubectl create secret generic "${SECRET_NAME}" \
  --namespace="${NAMESPACE}" \
  --from-literal=SPRING_DATASOURCE_URL="${JDBC_URL}" \
  --from-literal=SPRING_DATASOURCE_USERNAME="${DB_USER}" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="${DB_PASSWORD}" \
  --dry-run=client -o yaml
