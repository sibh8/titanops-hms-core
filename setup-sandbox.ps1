# MediCore HMS — Sandbox Setup Script (PowerShell)
# Starts MySQL, observability stack, and all 9 microservices via Docker Compose.
# Every variable can be pre-set as an environment variable to skip the prompt,
# or left unset to be prompted interactively.
#
# Usage:
#   .\setup-sandbox.ps1              # start the sandbox (skips prompts on 2nd+ run)
#   .\setup-sandbox.ps1 -Teardown    # stop and remove all sandbox containers
#   .\setup-sandbox.ps1 -Rebuild     # force Docker image rebuild even if images exist
#
# Skip prompts by pre-setting variables:
#   $env:SPRING_DATASOURCE_PASSWORD = "secret"
#   $env:PATIENT_SERVICE_PORT = "9081"
#   .\setup-sandbox.ps1

param(
    [switch]$Teardown,   # Stop and remove all sandbox containers, then exit
    [switch]$Rebuild     # Force --build even when images already exist
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Teardown mode ────────────────────────────────────────────────────────────
if ($Teardown) {
    Write-Host "Tearing down MediCore HMS sandbox..." -ForegroundColor Yellow
    $running = docker ps -q 2>$null
    if ($running) {
        docker stop $running | Out-Null
        Write-Host "  Stopped $($running.Count) container(s)." -ForegroundColor DarkGray
    }
    $all = docker ps -aq 2>$null
    if ($all) {
        docker rm $all | Out-Null
        Write-Host "  Removed $($all.Count) container(s)." -ForegroundColor DarkGray
    }
    if (-not $running -and -not $all) {
        Write-Host "  No containers found — nothing to do."
    }
    Write-Host "Teardown complete." -ForegroundColor Green
    exit 0
}

$EnvFile = Join-Path $PSScriptRoot ".sandbox.env"

# ─── Load saved config from previous run ──────────────────────────────────────
if (Test-Path $EnvFile) {
    Write-Host "Loading saved configuration from .sandbox.env (delete it to re-prompt)" -ForegroundColor DarkGray
    Get-Content $EnvFile | Where-Object { $_ -match '^\s*([^#=]+)=(.*)$' } | ForEach-Object {
        $key, $val = $_ -split '=', 2
        $key = $key.Trim()
        $val = $val.Trim()
        if (-not [System.Environment]::GetEnvironmentVariable($key)) {
            [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
            Set-Item -Path "Env:$key" -Value $val
        }
    }
}

# ─── Helper: prompt for a value if not already set in the environment ─────────
function Prompt-IfUnset {
    param(
        [string]$VarName,
        [string]$PromptText,
        [string]$DefaultValue,
        [bool]$IsSecret = $false
    )

    $current = [System.Environment]::GetEnvironmentVariable($VarName)
    if ([string]::IsNullOrEmpty($current)) {
        if ($IsSecret) {
            $secure = Read-Host "$PromptText [default: $DefaultValue]" -AsSecureString
            $plain  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                          [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
            $value  = if ([string]::IsNullOrEmpty($plain)) { $DefaultValue } else { $plain }
        } else {
            $input = Read-Host "$PromptText [default: $DefaultValue]"
            $value = if ([string]::IsNullOrEmpty($input)) { $DefaultValue } else { $input }
        }
        [System.Environment]::SetEnvironmentVariable($VarName, $value, "Process")
        Set-Item -Path "Env:$VarName" -Value $value
    } else {
        Write-Host "  $VarName already set via environment."
    }
}

# ─── Helper: write a section header ──────────────────────────────────────────
function Write-Header([string]$Text) {
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ("-" * $Text.Length) -ForegroundColor DarkCyan
}

# ─── Database ─────────────────────────────────────────────────────────────────
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host " MediCore HMS Sandbox — Configuration"        -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host "Press ENTER to accept the default value shown."
Write-Host ""
Write-Host "--- Database ---" -ForegroundColor Cyan

Prompt-IfUnset "MYSQL_DATABASE"             "MySQL database name"        "medicore_hms"
Prompt-IfUnset "SPRING_DATASOURCE_USERNAME" "MySQL application user"     "medicore"
Prompt-IfUnset "SPRING_DATASOURCE_PASSWORD" "MySQL application password" "medicore_pass" $true
Prompt-IfUnset "MYSQL_ROOT_PASSWORD"        "MySQL root password"        "root_pass"     $true
Prompt-IfUnset "MYSQL_PORT"                 "MySQL host port"            "3306"

# ─── Service Ports ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "--- Microservice Ports ---" -ForegroundColor Cyan

Prompt-IfUnset "PATIENT_SERVICE_PORT"       "Patient Service port"       "8081"
Prompt-IfUnset "APPOINTMENT_SERVICE_PORT"   "Appointment Service port"   "8082"
Prompt-IfUnset "USER_SERVICE_PORT"          "User Service port"          "8083"
Prompt-IfUnset "BILLING_SERVICE_PORT"       "Billing Service port"       "8084"
Prompt-IfUnset "ENCOUNTER_SERVICE_PORT"     "Encounter Service port"     "8085"
Prompt-IfUnset "LAB_SERVICE_PORT"           "Lab Service port"           "8086"
Prompt-IfUnset "MEDICATION_SERVICE_PORT"    "Medication Service port"    "8087"
Prompt-IfUnset "PRESCRIPTION_SERVICE_PORT" "Prescription Service port" "8088"
Prompt-IfUnset "PROVIDER_SERVICE_PORT"      "Provider Service port"      "8089"

# ─── Observability Ports ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "--- Observability Ports ---" -ForegroundColor Cyan

Prompt-IfUnset "FRONTEND_PORT"   "Frontend (UI) port"  "3000"
Prompt-IfUnset "GRAFANA_PORT"    "Grafana port"         "3001"
Prompt-IfUnset "PROMETHEUS_PORT" "Prometheus port"      "9090"
Prompt-IfUnset "JAEGER_UI_PORT"  "Jaeger UI port"       "16686"

# ─── Observability Credentials ────────────────────────────────────────────────
Write-Host ""
Write-Host "--- Observability Credentials ---" -ForegroundColor Cyan

Prompt-IfUnset "GRAFANA_ADMIN_PASSWORD" "Grafana admin password" "admin" $true

# ─── OTEL Settings ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "--- OpenTelemetry Settings ---" -ForegroundColor Cyan

Prompt-IfUnset "OTEL_EXPORTER_OTLP_ENDPOINT" "OTLP collector endpoint"            "http://otel-collector:4317"
Prompt-IfUnset "OTEL_TRACES_EXPORTER"        "Traces exporter (otlp/jaeger/none)" "otlp"
Prompt-IfUnset "OTEL_METRICS_EXPORTER"       "Metrics exporter (otlp/prometheus/none)" "otlp"
Prompt-IfUnset "OTEL_LOGS_EXPORTER"          "Logs exporter (otlp/none)"          "otlp"

Write-Host ""
Write-Host "All configuration confirmed. Starting services..." -ForegroundColor Green
Write-Host ""

# ─── Persist config for next run ──────────────────────────────────────────────
@"
MYSQL_DATABASE=$env:MYSQL_DATABASE
SPRING_DATASOURCE_USERNAME=$env:SPRING_DATASOURCE_USERNAME
SPRING_DATASOURCE_PASSWORD=$env:SPRING_DATASOURCE_PASSWORD
MYSQL_ROOT_PASSWORD=$env:MYSQL_ROOT_PASSWORD
MYSQL_PORT=$env:MYSQL_PORT
PATIENT_SERVICE_PORT=$env:PATIENT_SERVICE_PORT
APPOINTMENT_SERVICE_PORT=$env:APPOINTMENT_SERVICE_PORT
USER_SERVICE_PORT=$env:USER_SERVICE_PORT
BILLING_SERVICE_PORT=$env:BILLING_SERVICE_PORT
ENCOUNTER_SERVICE_PORT=$env:ENCOUNTER_SERVICE_PORT
LAB_SERVICE_PORT=$env:LAB_SERVICE_PORT
MEDICATION_SERVICE_PORT=$env:MEDICATION_SERVICE_PORT
PRESCRIPTION_SERVICE_PORT=$env:PRESCRIPTION_SERVICE_PORT
PROVIDER_SERVICE_PORT=$env:PROVIDER_SERVICE_PORT
FRONTEND_PORT=$env:FRONTEND_PORT
GRAFANA_PORT=$env:GRAFANA_PORT
PROMETHEUS_PORT=$env:PROMETHEUS_PORT
JAEGER_UI_PORT=$env:JAEGER_UI_PORT
GRAFANA_ADMIN_PASSWORD=$env:GRAFANA_ADMIN_PASSWORD
OTEL_EXPORTER_OTLP_ENDPOINT=$env:OTEL_EXPORTER_OTLP_ENDPOINT
OTEL_TRACES_EXPORTER=$env:OTEL_TRACES_EXPORTER
OTEL_METRICS_EXPORTER=$env:OTEL_METRICS_EXPORTER
OTEL_LOGS_EXPORTER=$env:OTEL_LOGS_EXPORTER
"@ | Set-Content $EnvFile
Write-Host "Configuration saved to .sandbox.env" -ForegroundColor DarkGray

# ─── MySQL ────────────────────────────────────────────────────────────────────
Write-Header "Starting MySQL..."
docker-compose up -d mysql
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to start MySQL"; exit 1 }

Write-Host "Waiting for MySQL to be ready..."
$maxAttempts = 24   # 2 minutes total
$attempt     = 0
$mysqlReady  = $false
while ($attempt -lt $maxAttempts) {
    $result = docker-compose exec -T mysql mysqladmin ping -h localhost `
                  -u $env:SPRING_DATASOURCE_USERNAME `
                  "-p$env:SPRING_DATASOURCE_PASSWORD" `
                  --silent 2>&1
    if ($LASTEXITCODE -eq 0) {
        $mysqlReady = $true
        break
    }
    $attempt++
    Write-Host "  MySQL not ready yet — retrying in 5s... ($attempt/$maxAttempts)"
    Start-Sleep -Seconds 5
}
if (-not $mysqlReady) { Write-Error "MySQL did not become ready in time."; exit 1 }
Write-Host "MySQL is ready." -ForegroundColor Green

# ─── Observability ────────────────────────────────────────────────────────────
Write-Header "Starting observability stack..."
docker-compose up -d jaeger otel-collector prometheus grafana
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to start observability stack"; exit 1 }

# ─── Microservices ────────────────────────────────────────────────────────────
Write-Header "Building and starting microservices..."
$imagesExist = docker images --format "{{.Repository}}" 2>$null | Where-Object { $_ -match 'java-microservices-patient-service' }
if ($Rebuild -or -not $imagesExist) {
    Write-Host "  (Building images from source...)" -ForegroundColor DarkYellow
    $buildFlag = @("--build")
} else {
    Write-Host "  (Images found — skipping rebuild. Use -Rebuild to force a fresh build.)" -ForegroundColor DarkGray
    $buildFlag = @()
}
$svcArgs = @("up", "-d") + $buildFlag + @(
    "patient-service",
    "appointment-service",
    "user-service",
    "billing-service",
    "encounter-service",
    "lab-service",
    "medication-service",
    "prescription-service",
    "provider-service"
)
& docker-compose @svcArgs
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to start microservices"; exit 1 }

# ─── Frontend ─────────────────────────────────────────────────────────────────
Write-Header "Building and starting frontend..."
$uiImageExists = docker images --format "{{.Repository}}" 2>$null | Where-Object { $_ -match 'java-microservices-medicore-hms-ui' }
$uiBuildFlag = if ($Rebuild -or -not $uiImageExists) { @("--build") } else { @() }
$uiArgs = @("up", "-d") + $uiBuildFlag + @("medicore-hms-ui")
& docker-compose @uiArgs
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to start frontend"; exit 1 }

# ─── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " MediCore HMS Sandbox is up and running"      -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "=== Database ===" -ForegroundColor Yellow
Write-Host "  Host:     localhost:$env:MYSQL_PORT"
Write-Host "  Database: $env:MYSQL_DATABASE"
Write-Host "  User:     $env:SPRING_DATASOURCE_USERNAME"
Write-Host "  Password: (as entered)"
Write-Host ""
Write-Host "=== Frontend ===" -ForegroundColor Yellow
Write-Host "  MediCore HMS UI:      http://localhost:$env:FRONTEND_PORT"
Write-Host ""
Write-Host "=== Observability ===" -ForegroundColor Yellow
Write-Host "  Jaeger UI:            http://localhost:$env:JAEGER_UI_PORT  (distributed tracing)"
Write-Host "  Grafana:              http://localhost:$env:GRAFANA_PORT    (admin / as entered)"
Write-Host "  Prometheus:           http://localhost:$env:PROMETHEUS_PORT"
Write-Host ""
Write-Host "=== OTEL ===" -ForegroundColor Yellow
Write-Host "  Collector endpoint:   $env:OTEL_EXPORTER_OTLP_ENDPOINT"
Write-Host "  Traces exporter:      $env:OTEL_TRACES_EXPORTER"
Write-Host "  Metrics exporter:     $env:OTEL_METRICS_EXPORTER"
Write-Host "  Logs exporter:        $env:OTEL_LOGS_EXPORTER"
Write-Host ""
Write-Host "=== Microservices ===" -ForegroundColor Yellow
Write-Host "  Patient Service:      http://localhost:$env:PATIENT_SERVICE_PORT/api/patients"
Write-Host "  Appointment Service:  http://localhost:$env:APPOINTMENT_SERVICE_PORT/api/appointments"
Write-Host "  User Service:         http://localhost:$env:USER_SERVICE_PORT/api/users"
Write-Host "  Billing Service:      http://localhost:$env:BILLING_SERVICE_PORT/api/invoices"
Write-Host "  Encounter Service:    http://localhost:$env:ENCOUNTER_SERVICE_PORT/api/encounters"
Write-Host "  Lab Service:          http://localhost:$env:LAB_SERVICE_PORT/api/labs/orders"
Write-Host "  Medication Service:   http://localhost:$env:MEDICATION_SERVICE_PORT/api/medications"
Write-Host "  Prescription Service: http://localhost:$env:PRESCRIPTION_SERVICE_PORT/api/prescriptions"
Write-Host "  Provider Service:     http://localhost:$env:PROVIDER_SERVICE_PORT/api/providers"
Write-Host ""
