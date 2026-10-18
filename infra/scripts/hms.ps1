#Requires -Version 7.0
<#
.SYNOPSIS
  Wrapper to run the TitanOps HMS Terraform stack for a specific environment.

.DESCRIPTION
  Resolves the stack directory, validates the environment exists, then runs the
  requested Terraform action with -var env=<env>. The DB password is read from
  the TF_VAR_db_password env var (never passed on the command line).

.PARAMETER Environment
  Environment under infra/environments (e.g. dev, local).

.PARAMETER Action
  Terraform action: init | plan | apply | destroy | fmt | validate | output | console.

.EXAMPLE
  ./hms.ps1 -Environment local -Action apply
  ./hms.ps1 dev plan
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Environment,

  [Parameter(Mandatory = $true, Position = 1)]
  [ValidateSet('init', 'plan', 'apply', 'destroy', 'fmt', 'validate', 'output', 'console')]
  [string]$Action,

  # Any extra args passed straight to terraform (e.g. -auto-approve)
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Extra
)

$ErrorActionPreference = 'Stop'

# ---- Resolve paths relative to this script ----
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraRoot = Split-Path -Parent $ScriptDir
$StackDir = Join-Path $InfraRoot 'infra-stack/hms-core-stack'
$EnvDir = Join-Path $InfraRoot "environments/$Environment"

# ---- Validation ----
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "terraform not found on PATH. Install Terraform >= 1.5."
}
if (-not (Test-Path (Join-Path $EnvDir 'infra-config/config.yaml'))) {
  throw "Environment '$Environment' not found. Expected: $EnvDir/infra-config/config.yaml"
}

Write-Host "==> Environment : $Environment" -ForegroundColor Cyan
Write-Host "==> Action      : $Action" -ForegroundColor Cyan
Write-Host "==> Stack       : $StackDir" -ForegroundColor Cyan

# ---- Build the terraform invocation ----
$chdir = "-chdir=$StackDir"
$tfVar = "-var", "env=$Environment"

$backendHcl = Join-Path $EnvDir 'backend.hcl'
$backendArgs = if (Test-Path $backendHcl) { @("-backend-config=$backendHcl") } else { @() }

switch ($Action) {
  'init' { $cmd = @($chdir, 'init') + $backendArgs + $Extra }
  'fmt' { $cmd = @($chdir, 'fmt', '-recursive') + $Extra }
  'validate' { $cmd = @($chdir, 'validate') + $Extra }
  'console' { $cmd = @($chdir, 'console') + $tfVar + $Extra }
  'output' { $cmd = @($chdir, 'output') + $Extra }
  'plan' { $cmd = @($chdir, 'plan') + $tfVar + $Extra }
  'apply' { $cmd = @($chdir, 'apply') + $tfVar + $Extra }
  'destroy' { $cmd = @($chdir, 'destroy') + $tfVar + $Extra }
}

# Auto-init if the working dir isn't initialized yet (for non-init actions).
if ($Action -ne 'init' -and -not (Test-Path (Join-Path $StackDir '.terraform'))) {
  Write-Host "==> .terraform missing - running init first" -ForegroundColor Yellow
  terraform $chdir init @backendArgs
}

Write-Host "==> terraform $($cmd -join ' ')" -ForegroundColor Green
terraform @cmd
exit $LASTEXITCODE
