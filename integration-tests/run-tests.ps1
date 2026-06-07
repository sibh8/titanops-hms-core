# run-tests.ps1 — Run MediCore integration tests on Windows
#
# Usage:
#   .\run-tests.ps1                          # all tests
#   .\run-tests.ps1 -Suites health           # health checks only
#   .\run-tests.ps1 -Suites cross            # cross-service workflow only
#   .\run-tests.ps1 -Suites users,providers  # specific suites
#   .\run-tests.ps1 -WaitForServices         # poll services until healthy before running
#
# Environment overrides:
#   $env:PATIENT_URL = "http://localhost:8081"
#
param(
    [string[]] $Suites = @(),
    [switch]   $WaitForServices
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot

# ── Node version check ────────────────────────────────────────────────────────
$nodePath = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodePath) {
    Write-Error "Node.js is not installed or not on PATH."
    exit 1
}
$nodeVersion = (node --version) -replace 'v','' -split '\.' | Select-Object -First 1
if ([int]$nodeVersion -lt 18) {
    Write-Error "Node.js 18+ is required. Found: $(node --version)"
    exit 1
}

# ── Service URL defaults ──────────────────────────────────────────────────────
$ServiceUrls = @{
    patient      = $env:PATIENT_URL      ?? 'http://localhost:8081'
    appointment  = $env:APPOINTMENT_URL  ?? 'http://localhost:8082'
    user         = $env:USER_URL         ?? 'http://localhost:8083'
    billing      = $env:BILLING_URL      ?? 'http://localhost:8084'
    encounter    = $env:ENCOUNTER_URL    ?? 'http://localhost:8085'
    lab          = $env:LAB_URL          ?? 'http://localhost:8086'
    medication   = $env:MEDICATION_URL   ?? 'http://localhost:8087'
    prescription = $env:PRESCRIPTION_URL ?? 'http://localhost:8088'
    provider     = $env:PROVIDER_URL     ?? 'http://localhost:8089'
}

# ── Wait for services ─────────────────────────────────────────────────────────
function Wait-ForService([string]$Name, [string]$BaseUrl) {
    $url      = "$BaseUrl/actuator/health"
    $attempts = 0
    Write-Host -NoNewline "  Waiting for $Name ..."
    while ($true) {
        try {
            $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($resp.StatusCode -eq 200) { Write-Host " UP"; return }
        } catch {}
        $attempts++
        if ($attempts -ge 24) { Write-Host " TIMEOUT"; throw "Service $Name did not become healthy within 2 minutes." }
        Start-Sleep -Seconds 5
        Write-Host -NoNewline "."
    }
}

if ($WaitForServices) {
    Write-Host "Waiting for all services to become healthy..."
    foreach ($svc in $ServiceUrls.GetEnumerator()) {
        Wait-ForService -Name "$($svc.Key)-service" -BaseUrl $svc.Value
    }
    Write-Host ""
}

# ── Suite map ─────────────────────────────────────────────────────────────────
$SuiteMap = [ordered]@{
    health        = '00-health.test.js'
    users         = '01-users.test.js'
    providers     = '02-providers.test.js'
    patients      = '03-patients.test.js'
    appointments  = '04-appointments.test.js'
    encounters    = '05-encounters.test.js'
    lab           = '06-lab.test.js'
    medications   = '07-medications.test.js'
    prescriptions = '08-prescriptions.test.js'
    billing       = '09-billing.test.js'
    cross         = '10-cross-service.test.js'
}

# ── Build file list ───────────────────────────────────────────────────────────
$Files = @()
if ($Suites.Count -eq 0) {
    $Files = $SuiteMap.Values | ForEach-Object { Join-Path $Root "tests\$_" }
} else {
    foreach ($suite in $Suites) {
        if (-not $SuiteMap.Contains($suite)) {
            Write-Error "Unknown suite '$suite'. Valid: $($SuiteMap.Keys -join ', ')"
            exit 1
        }
        $Files += Join-Path $Root "tests\$($SuiteMap[$suite])"
    }
}

Write-Host "=================================================="
Write-Host " MediCore Integration Tests"
Write-Host "=================================================="
Write-Host "Running $($Files.Count) suite(s)..."
Write-Host ""

$argList = @('--test', '--test-reporter=spec') + $Files

$process = Start-Process -FilePath 'node' -ArgumentList $argList -NoNewWindow -PassThru -Wait
exit $process.ExitCode
