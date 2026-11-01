<#
.SYNOPSIS
    Builds the entire MediCore HMS codebase locally (no Docker, no containers).

.DESCRIPTION
    Compiles and packages all 9 Java/Maven microservices using each service's
    Maven wrapper (mvnw), and builds the React/Vite frontend with npm.
    This only produces build artifacts on your machine; it does not build
    Docker images or start any containers.

.PARAMETER SkipTests
    Skip unit tests during the Maven build (faster). Default: $true.

.PARAMETER SkipFrontend
    Skip the frontend (npm) build. Default: $false.

.PARAMETER Clean
    Run a clean build (mvn clean package). Default: $true.

.EXAMPLE
    ./build-all-local.ps1
    ./build-all-local.ps1 -SkipTests:$false
    ./build-all-local.ps1 -SkipFrontend
#>

param(
    [bool]$SkipTests = $true,
    [switch]$SkipFrontend,
    [bool]$Clean = $true
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  MediCore HMS - Local Codebase Build  " -ForegroundColor Cyan
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

$mvnGoals = @()
if ($Clean) { $mvnGoals += "clean" }
$mvnGoals += "package"
if ($SkipTests) { $mvnGoals += "-DskipTests" }

Write-Host "Build plan:" -ForegroundColor Yellow
Write-Host "  - $($services.Count) Maven microservices  (mvn $($mvnGoals -join ' '))" -ForegroundColor Yellow
if (-not $SkipFrontend) {
    Write-Host "  - frontend (npm ci && npm run build)" -ForegroundColor Yellow
}
Write-Host ""

$results = [System.Collections.Generic.List[object]]::new()
$failures = 0

# ─── Build Java microservices ────────────────────────────────────────────────
Write-Host "=== Building Maven microservices ===" -ForegroundColor Cyan
Write-Host ""

foreach ($service in $services) {
    $servicePath = Join-Path $repoRoot $service
    Write-Host "Building $service..." -ForegroundColor Green

    if (-not (Test-Path $servicePath)) {
        Write-Host "  x $service - directory not found, skipping" -ForegroundColor Red
        $results.Add([pscustomobject]@{ Name = $service; Status = "MISSING" })
        $failures++
        continue
    }

    Push-Location $servicePath
    try {
        # Prefer the Maven wrapper so no global Maven install is required.
        $mvnCmd = Join-Path $servicePath "mvnw.cmd"
        if (Test-Path $mvnCmd) {
            & $mvnCmd @mvnGoals
        } else {
            & mvn @mvnGoals
        }
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Host "  + $service built successfully" -ForegroundColor Green
            $results.Add([pscustomobject]@{ Name = $service; Status = "OK" })
        } else {
            Write-Host "  x $service build FAILED (exit $exitCode)" -ForegroundColor Red
            $results.Add([pscustomobject]@{ Name = $service; Status = "FAILED" })
            $failures++
        }
    }
    finally {
        Pop-Location
    }
    Write-Host ""
}

# ─── Build frontend ──────────────────────────────────────────────────────────
if (-not $SkipFrontend) {
    Write-Host "=== Building frontend ===" -ForegroundColor Cyan
    Write-Host ""

    $frontendPath = Join-Path $repoRoot "frontend"
    if (-not (Test-Path (Join-Path $frontendPath "package.json"))) {
        Write-Host "  x frontend - package.json not found, skipping" -ForegroundColor Red
        $results.Add([pscustomobject]@{ Name = "frontend"; Status = "MISSING" })
        $failures++
    } else {
        Push-Location $frontendPath
        try {
            # Use npm ci for a clean, reproducible install when a lockfile exists.
            if (Test-Path (Join-Path $frontendPath "package-lock.json")) {
                npm ci
            } else {
                npm install
            }

            if ($LASTEXITCODE -eq 0) {
                npm run build
            }

            if ($LASTEXITCODE -eq 0) {
                Write-Host "  + frontend built successfully" -ForegroundColor Green
                $results.Add([pscustomobject]@{ Name = "frontend"; Status = "OK" })
            } else {
                Write-Host "  x frontend build FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
                $results.Add([pscustomobject]@{ Name = "frontend"; Status = "FAILED" })
                $failures++
            }
        }
        finally {
            Pop-Location
        }
        Write-Host ""
    }
}

# ─── Summary ─────────────────────────────────────────────────────────────────
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "             BUILD SUMMARY             " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
foreach ($r in $results) {
    $color = switch ($r.Status) {
        "OK"      { "Green" }
        default   { "Red" }
    }
    Write-Host ("  {0,-22} {1}" -f $r.Name, $r.Status) -ForegroundColor $color
}
Write-Host ""

if ($failures -gt 0) {
    Write-Host "$failures component(s) failed to build." -ForegroundColor Red
    exit 1
}

Write-Host "All components built successfully." -ForegroundColor Green
exit 0
