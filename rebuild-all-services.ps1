# Script to rebuild all microservices with Maven and Docker

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  MediCore HMS - Rebuild All Services  " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$services = @(
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

Write-Host "This script will:" -ForegroundColor Yellow
Write-Host "  1. Build all 9 services with Maven" -ForegroundColor Yellow
Write-Host "  2. Rebuild all Docker images" -ForegroundColor Yellow
Write-Host "  3. Restart all containers" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Continue? (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "Cancelled." -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "=== STEP 1: Building services with Maven ===" -ForegroundColor Cyan
Write-Host ""

$buildErrors = 0
foreach ($service in $services) {
    Write-Host "Building $service..." -ForegroundColor Green
    Push-Location $service
    
    $output = mvn clean package -DskipTests 2>&1
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "  ✓ $service built successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $service build FAILED" -ForegroundColor Red
        $buildErrors++
        Write-Host "  Error output: $output" -ForegroundColor Red
    }
    
    Pop-Location
}

Write-Host ""
if ($buildErrors -gt 0) {
    Write-Host "⚠ $buildErrors service(s) failed to build. Fix errors and try again." -ForegroundColor Red
    exit 1
}

Write-Host "=== STEP 2: Rebuilding Docker images ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Rebuilding all Docker images..." -ForegroundColor Green
docker-compose build

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== STEP 3: Restarting containers ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Stopping all containers..." -ForegroundColor Green
docker-compose down

Write-Host "Starting all containers..." -ForegroundColor Green
docker-compose up -d

Write-Host ""
Write-Host "=== Waiting for services to start ===" -ForegroundColor Cyan
Write-Host "Waiting 60 seconds for all services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

Write-Host ""
Write-Host "=== Verifying health endpoints ===" -ForegroundColor Cyan
Write-Host ""

$healthyCount = 0
foreach ($service in $services) {
    $port = switch ($service) {
        "patient-service" { 8081 }
        "appointment-service" { 8082 }
        "user-service" { 8083 }
        "billing-service" { 8084 }
        "encounter-service" { 8085 }
        "lab-service" { 8086 }
        "medication-service" { 8087 }
        "prescription-service" { 8088 }
        "provider-service" { 8089 }
    }
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/actuator/health" -Method Get -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host "  ✓ $service - Health endpoint responding (200 OK)" -ForegroundColor Green
            $healthyCount++
        } else {
            Write-Host "  ⚠ $service - Health endpoint returned $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ $service - Health endpoint not available" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "           REBUILD COMPLETE            " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Healthy services: $healthyCount / $($services.Count)" -ForegroundColor $(if ($healthyCount -eq $services.Count) { "Green" } else { "Yellow" })
Write-Host ""
Write-Host "Access your application at:" -ForegroundColor Cyan
Write-Host "  • Frontend: http://localhost:3000" -ForegroundColor White
Write-Host "  • Grafana:  http://localhost:3001 (admin/admin)" -ForegroundColor White
Write-Host "  • Prometheus: http://localhost:9090" -ForegroundColor White
Write-Host "  • Jaeger: http://localhost:16686" -ForegroundColor White
Write-Host ""
Write-Host "Check Service Status dashboard: http://localhost:3000/service-status" -ForegroundColor Yellow
Write-Host ""
