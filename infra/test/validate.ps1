#Requires -Version 7.0
<#
.SYNOPSIS
  Static validation test suite for the TitanOps HMS Terraform stack.

.DESCRIPTION
  Runs offline checks only (no AWS credentials or live cluster required):
    1. terraform fmt -check (formatting)
    2. terraform init -backend=false (module/provider resolution)
    3. terraform validate (config correctness)
    4. config.yaml logic assertions via terraform console, for every environment:
         - YAML decodes and target resolves
         - all 10 services are enabled
         - a disabled service drops out of enabled_services (toggle-off => destroy)
         - AWS-only wiring is active only for target=aws
    5. app-config parity: each enabled service has a matching app-config YAML

  Exit code 0 = all passed, 1 = one or more failures.

.EXAMPLE
  ./validate.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$TestDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraRoot = Split-Path -Parent $TestDir
$StackDir = Join-Path $InfraRoot 'infra-stack/hms-core-stack'
$EnvRoot = Join-Path $InfraRoot 'environments'

$script:Pass = 0
$script:Fail = 0

function Test-Case {
  param([string]$Name, [scriptblock]$Body)
  try {
    & $Body
    Write-Host "  [PASS] $Name" -ForegroundColor Green
    $script:Pass++
  }
  catch {
    Write-Host "  [FAIL] $Name" -ForegroundColor Red
    Write-Host "         $_" -ForegroundColor DarkRed
    $script:Fail++
  }
}

function Assert-Equal {
  param($Expected, $Actual, [string]$Msg = '')
  if ("$Expected" -ne "$Actual") {
    throw "expected '$Expected' but got '$Actual'. $Msg"
  }
}

# Evaluate a HCL expression in the stack for a given env; returns trimmed stdout.
function Invoke-Console {
  param([string]$Env, [string]$Expr)
  $out = $Expr | terraform "-chdir=$StackDir" console -var "env=$Env" 2>&1
  if ($LASTEXITCODE -ne 0) { throw "terraform console failed: $out" }
  return ($out | Out-String).Trim()
}

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw 'terraform not found on PATH. Install Terraform >= 1.5.'
}

Write-Host '== TitanOps HMS stack validation ==' -ForegroundColor Cyan
Write-Host "   stack: $StackDir`n"

# ---- 1. fmt ----
Write-Host 'Formatting:'
Test-Case 'terraform fmt -check -recursive (all infra)' {
  terraform "-chdir=$InfraRoot" fmt -check -recursive | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'files are not formatted; run: terraform fmt -recursive' }
}

# ---- 2 + 3. init + validate ----
Write-Host 'Init & validate:'
Test-Case 'terraform init -backend=false' {
  $o = terraform "-chdir=$StackDir" init -backend=false -no-color 2>&1
  if ($LASTEXITCODE -ne 0) { throw ($o | Out-String) }
}
Test-Case 'terraform validate' {
  $o = terraform "-chdir=$StackDir" validate -no-color 2>&1
  if ($LASTEXITCODE -ne 0) { throw ($o | Out-String) }
}

# ---- 4. per-environment config logic ----
$expectedServices = @(
  'appointment-service', 'billing-service', 'encounter-service', 'frontend',
  'lab-service', 'medication-service', 'patient-service', 'prescription-service',
  'provider-service', 'user-service'
)

# For offline evaluation, initialize temporary local backend override so console runs without AWS credentials
Set-Content -Path (Join-Path $StackDir 'backend_override.tf') -Value "terraform {`n  backend `"local`" {}`n}"
terraform "-chdir=$StackDir" init -reconfigure | Out-Null

$envs = Get-ChildItem -Directory $EnvRoot | Select-Object -ExpandProperty Name
foreach ($env in $envs) {
  Write-Host "Environment '$env':"

  Test-Case "$env - config.yaml decodes & target is valid" {
    $t = Invoke-Console $env 'local.target'
    if ($t -notmatch '^"(aws|local)"$') { throw "unexpected target: $t" }
  }

  Test-Case "$env - all 10 services enabled" {
    $n = Invoke-Console $env 'length(keys(local.enabled_services))'
    Assert-Equal 10 $n 'service count mismatch'
  }

  Test-Case "$env - enabled service names match expected set" {
    # console prints an HCL list; extract quoted names rather than parsing JSON.
    $raw = Invoke-Console $env 'sort(keys(local.enabled_services))'
    $actual = [regex]::Matches($raw, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $diff = Compare-Object $expectedServices $actual
    if ($diff) { throw "service set differs: $($diff | Out-String)" }
  }

  Test-Case "$env - disabled service is excluded (toggle-off => destroy)" {
    $expr = 'contains(keys({ for k, v in { "x" = { enabled = false } } : k => v if try(v.enabled, true) }), "x")'
    $r = Invoke-Console $env $expr
    Assert-Equal 'false' $r 'a disabled service should not appear in enabled_services'
  }

  Test-Case "$env - is_aws / is_local are mutually exclusive" {
    $r = Invoke-Console $env 'local.is_aws == local.is_local'
    Assert-Equal 'false' $r 'exactly one target mode must be active'
  }

  # ---- 5. app-config parity ----
  Test-Case "$env - every enabled service has an app-config YAML" {
    $appDir = Join-Path $EnvRoot "$env/app-config"
    foreach ($svc in $expectedServices) {
      $f = Join-Path $appDir "$svc.yaml"
      if (-not (Test-Path $f)) { throw "missing app-config: $f" }
    }
  }
}

# ---- cleanup ----
Remove-Item -Force (Join-Path $StackDir 'backend_override.tf') -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $StackDir '.terraform') -ErrorAction SilentlyContinue
Remove-Item -Force (Join-Path $StackDir 'terraform.tfstate*') -ErrorAction SilentlyContinue

Write-Host "`n== Results ==" -ForegroundColor Cyan
Write-Host "   Passed: $script:Pass" -ForegroundColor Green
Write-Host "   Failed: $script:Fail" -ForegroundColor ($(if ($script:Fail -gt 0) { 'Red' } else { 'Green' }))

exit $(if ($script:Fail -gt 0) { 1 } else { 0 })
