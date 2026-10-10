#Requires -Version 7.0
<#
.SYNOPSIS
  AWS smoke test + CIS benchmark checks for a DEPLOYED TitanOps HMS stack.

.DESCRIPTION
  Verifies real AWS resources against the stack's intent and the CIS Level 1
  controls baked into the Terraform modules (VPC flow logs, restricted default
  SG, no world-open SSH, EKS audit logging/private endpoint/IMDSv2, RDS
  encryption/private/multi-AZ/backups/deletion-protection, ECR scan+immutable,
  GitHub OIDC, and optional GuardDuty/Security Hub).

  Requirements: applied AWS environment, aws CLI v2 (read access), terraform.

.PARAMETER Environment
  AWS environment to test (default: dev).

.EXAMPLE
  ./smoke-aws.ps1
  ./smoke-aws.ps1 -Environment dev
#>
[CmdletBinding()]
param([Parameter(Position = 0)][string]$Environment = 'dev')

$ErrorActionPreference = 'Stop'

$TestDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraRoot = Split-Path -Parent $TestDir
$StackDir = Join-Path $InfraRoot 'infra-stack/hms-core-stack'

$script:Pass = 0; $script:Fail = 0; $script:Skip = 0

function P { param($m) Write-Host "  [PASS] $m" -ForegroundColor Green;  $script:Pass++ }
function F { param($m, $d) Write-Host "  [FAIL] $m" -ForegroundColor Red; if ($d) { Write-Host "         $d" -ForegroundColor DarkRed }; $script:Fail++ }
function S { param($m, $d) Write-Host "  [SKIP] $m" -ForegroundColor Yellow; if ($d) { Write-Host "         $d" -ForegroundColor DarkYellow }; $script:Skip++ }
function AssertEq { param($Expected, $Actual, $Name) if ("$Expected" -eq "$Actual") { P $Name } else { F $Name "expected '$Expected', got '$Actual'" } }

foreach ($t in 'aws', 'terraform') {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "Required tool '$t' not found on PATH." }
}

function TfOut { param($name) (terraform "-chdir=$StackDir" output -raw $name 2>$null) }
# Run aws CLI and return trimmed text output
function Aws { param([string[]]$Args) (& aws @Args --output text 2>$null | Out-String).Trim() }

Write-Host '== TitanOps HMS - AWS smoke & CIS checks ==' -ForegroundColor Cyan
Write-Host "   environment: $Environment`n"

$target = TfOut 'target'
if ($target -ne 'aws') {
  Write-Host "Stack target is '$target', not 'aws'. Apply the AWS env first:" -ForegroundColor Red
  Write-Host "  infra/scripts/hms.ps1 $Environment apply" -ForegroundColor Red
  exit 1
}

$Region = TfOut 'region'; $env:AWS_DEFAULT_REGION = $Region
$VpcId = TfOut 'vpc_id'
$Cluster = TfOut 'cluster_name'
$RdsId = TfOut 'rds_identifier'
Write-Host "   region=$Region vpc=$VpcId cluster=$Cluster rds=$RdsId`n"

# ---- VPC / networking ----
Write-Host 'VPC / networking:'
AssertEq 'available' (Aws @('ec2', 'describe-vpcs', '--vpc-ids', $VpcId, '--query', 'Vpcs[0].State')) 'VPC exists and is available'

$fl = Aws @('ec2', 'describe-flow-logs', '--filter', "Name=resource-id,Values=$VpcId", '--query', 'length(FlowLogs)')
if ([int]($fl | ForEach-Object { $_ -as [int] }) -ge 1) { P 'CIS 3.9 - VPC flow logs enabled' } else { F 'CIS 3.9 - VPC flow logs enabled' "none on $VpcId" }

$dsg = Aws @('ec2', 'describe-security-groups', '--filters', "Name=vpc-id,Values=$VpcId", 'Name=group-name,Values=default', '--query', 'SecurityGroups[0].[length(IpPermissions),length(IpPermissionsEgress)]')
if ($dsg -match '^0\s+0$') { P 'CIS 5.3 - default SG has no in/egress rules' } else { F 'CIS 5.3 - default SG has no in/egress rules' "rules: $dsg" }

$openSsh = Aws @('ec2', 'describe-security-groups', '--filters', "Name=vpc-id,Values=$VpcId", '--query', "SecurityGroups[?IpPermissions[?FromPort<=``22`` && ToPort>=``22`` && IpRanges[?CidrIp=='0.0.0.0/0']]].GroupId")
if ([string]::IsNullOrWhiteSpace($openSsh)) { P 'CIS 5.2 - no SG opens SSH (22) to the world' } else { F 'CIS 5.2 - no SG opens SSH (22) to the world' "offending: $openSsh" }

# ---- EKS ----
Write-Host 'EKS:'
AssertEq 'ACTIVE' (Aws @('eks', 'describe-cluster', '--name', $Cluster, '--query', 'cluster.status')) 'EKS cluster is ACTIVE'

$audit = Aws @('eks', 'describe-cluster', '--name', $Cluster, '--query', "cluster.logging.clusterLogging[?enabled].types[]")
if ($audit -match 'audit') { P 'CIS EKS 2.1.1 - audit logging enabled' } else { F 'CIS EKS 2.1.1 - audit logging enabled' "enabled: $audit" }

$enc = Aws @('eks', 'describe-cluster', '--name', $Cluster, '--query', 'length(cluster.encryptionConfig)')
if (($enc -as [int]) -ge 1) { P 'CIS EKS - secrets encrypted with KMS' } else { S 'CIS EKS - secrets encrypted with KMS' 'no encryptionConfig (set kms_key_arn to enable)' }

AssertEq 'False' (Aws @('eks', 'describe-cluster', '--name', $Cluster, '--query', 'cluster.resourcesVpcConfig.endpointPublicAccess')) 'CIS EKS 5.4.1 - API endpoint public access disabled'

$ltIds = (Aws @('ec2', 'describe-launch-templates', '--query', "LaunchTemplates[?starts_with(LaunchTemplateName, '$Cluster')].LaunchTemplateId")) -split '\s+' | Where-Object { $_ }
if ($ltIds) {
  $ok = $true
  foreach ($lt in $ltIds) {
    $tok = Aws @('ec2', 'describe-launch-template-versions', '--launch-template-id', $lt, '--versions', '$Latest', '--query', 'LaunchTemplateVersions[0].LaunchTemplateData.MetadataOptions.HttpTokens')
    if ($tok -ne 'required') { $ok = $false }
  }
  if ($ok) { P 'CIS - worker nodes enforce IMDSv2' } else { F 'CIS - worker nodes enforce IMDSv2' 'HttpTokens not required' }
}
else { S 'CIS - worker nodes enforce IMDSv2' 'no launch templates found' }

# ---- RDS ----
Write-Host 'RDS:'
AssertEq 'available' (Aws @('rds', 'describe-db-instances', '--db-instance-identifier', $RdsId, '--query', 'DBInstances[0].DBInstanceStatus')) 'RDS instance is available'
AssertEq 'True'  (Aws @('rds', 'describe-db-instances', '--db-instance-identifier', $RdsId, '--query', 'DBInstances[0].StorageEncrypted'))   'CIS RDS - storage encrypted at rest'
AssertEq 'False' (Aws @('rds', 'describe-db-instances', '--db-instance-identifier', $RdsId, '--query', 'DBInstances[0].PubliclyAccessible')) 'CIS RDS - not publicly accessible'
AssertEq 'True'  (Aws @('rds', 'describe-db-instances', '--db-instance-identifier', $RdsId, '--query', 'DBInstances[0].MultiAZ'))            'CIS RDS - Multi-AZ enabled'
$bk = Aws @('rds', 'describe-db-instances', '--db-instance-identifier', $RdsId, '--query', 'DBInstances[0].BackupRetentionPeriod')
if (($bk -as [int]) -ge 1) { P "CIS RDS - automated backups enabled ($bk days)" } else { F 'CIS RDS - automated backups enabled' "retention: $bk" }
AssertEq 'True'  (Aws @('rds', 'describe-db-instances', '--db-instance-identifier', $RdsId, '--query', 'DBInstances[0].DeletionProtection')) 'CIS RDS - deletion protection enabled'

# ---- ECR ----
Write-Host 'ECR:'
$repos = (Aws @('ecr', 'describe-repositories', '--query', 'repositories[].repositoryName')) -split '\s+' | Where-Object { $_ -like '*titanops-hms/*' }
if ($repos) {
  $scanOk = $true; $immutOk = $true
  foreach ($r in $repos) {
    if ((Aws @('ecr', 'describe-repositories', '--repository-names', $r, '--query', 'repositories[0].imageScanningConfiguration.scanOnPush')) -ne 'True') { $scanOk = $false }
    if ((Aws @('ecr', 'describe-repositories', '--repository-names', $r, '--query', 'repositories[0].imageTagMutability')) -ne 'IMMUTABLE') { $immutOk = $false }
  }
  if ($scanOk) { P "CIS ECR - scan on push enabled ($($repos.Count) repos)" } else { F 'CIS ECR - scan on push enabled' 'a repo has scanOnPush=false' }
  if ($immutOk) { P "CIS ECR - image tags immutable ($($repos.Count) repos)" } else { F 'CIS ECR - image tags immutable' 'a repo is MUTABLE' }
}
else { S 'CIS ECR - repo checks' 'no titanops-hms repositories found' }

# ---- IAM / OIDC ----
Write-Host 'IAM / OIDC:'
$oidc = Aws @('iam', 'list-open-id-connect-providers', '--query', "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')] | length(@)")
if (($oidc -as [int]) -ge 1) { P 'CIS IAM - GitHub OIDC provider present (no static keys)' } else { F 'CIS IAM - GitHub OIDC provider present' 'not found' }

# ---- Optional features ----
Write-Host 'Optional security features (as configured):'
$gd = Aws @('guardduty', 'list-detectors', '--query', 'length(DetectorIds)')
if (($gd -as [int]) -ge 1) { P 'CIS - GuardDuty detector enabled' } else { S 'CIS - GuardDuty detector' 'disabled in config (feature off)' }
$sh = Aws @('securityhub', 'get-enabled-standards', '--query', 'length(StandardsSubscriptions)')
if (($sh -as [int]) -ge 1) { P 'CIS - Security Hub CIS standard subscribed' } else { S 'CIS - Security Hub' 'disabled in config (feature off)' }

# ---- Results ----
Write-Host "`n== Results ==" -ForegroundColor Cyan
Write-Host "   Passed: $script:Pass   Skipped: $script:Skip   Failed: $script:Fail" -ForegroundColor $(if ($script:Fail -gt 0) { 'Red' } else { 'Green' })
exit $(if ($script:Fail -gt 0) { 1 } else { 0 })
