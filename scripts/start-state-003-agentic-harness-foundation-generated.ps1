#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [switch]$DryRun,
  [switch]$BuildOnly
)

. "$PSScriptRoot/lib/runtime-common.ps1"

$repoRoot = Get-TraderxRepoRoot -ScriptPath $PSCommandPath
$generatedRoot = Get-TraderxGeneratedRoot -RepoRoot $repoRoot
$sourceRepoRoot = if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('TRADERX_SOURCE_REPO_ROOT'))) { $repoRoot } else { [Environment]::GetEnvironmentVariable('TRADERX_SOURCE_REPO_ROOT') }
Use-GeneratedRuntimeScript -ScriptPath $PSCommandPath -GeneratedRoot $generatedRoot -RepoRoot $repoRoot -ScriptArgs $args -AdditionalEnv @{ TRADERX_SOURCE_REPO_ROOT = $sourceRepoRoot }

$target = Join-Path $generatedRoot 'code/target-generated'
$expectedState = '003-agentic-harness-foundation'
$edgeComponentDir = Join-Path $generatedRoot 'code/components/edge-proxy-specfirst'
$edgeTargetDir = Join-Path $target 'edge-proxy'
$edgeProxyPort = if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('EDGE_PROXY_PORT'))) { 18080 } else { [int][Environment]::GetEnvironmentVariable('EDGE_PROXY_PORT') }

if (-not (Test-Path -LiteralPath $edgeComponentDir -PathType Container)) {
  throw "[error] missing generated edge-proxy component: $edgeComponentDir`n[hint] run: bash pipeline/generate-state.sh 003-agentic-harness-foundation"
}

$baseStartScript = Join-Path $repoRoot 'scripts/start-base-uncontainerized-generated.ps1'
$priorExpected = [Environment]::GetEnvironmentVariable('TRADERX_EXPECTED_STATE_ID')
$priorGenerated = [Environment]::GetEnvironmentVariable('TRADERX_GENERATED_ROOT')
$priorSource = [Environment]::GetEnvironmentVariable('TRADERX_SOURCE_REPO_ROOT')

[Environment]::SetEnvironmentVariable('TRADERX_EXPECTED_STATE_ID', $expectedState)
[Environment]::SetEnvironmentVariable('TRADERX_GENERATED_ROOT', $generatedRoot)
[Environment]::SetEnvironmentVariable('TRADERX_SOURCE_REPO_ROOT', $sourceRepoRoot)

try {
  $baseArgs = @()
  if ($DryRun) { $baseArgs += '-DryRun' }
  if ($BuildOnly) { $baseArgs += '-BuildOnly' }
  & $baseStartScript @baseArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  [Environment]::SetEnvironmentVariable('TRADERX_EXPECTED_STATE_ID', $priorExpected)
  [Environment]::SetEnvironmentVariable('TRADERX_GENERATED_ROOT', $priorGenerated)
  [Environment]::SetEnvironmentVariable('TRADERX_SOURCE_REPO_ROOT', $priorSource)
}

$runRoot = [Environment]::GetEnvironmentVariable('TRADERX_RUN_DIR')
if ([string]::IsNullOrWhiteSpace($runRoot)) {
  if ($IsWindows) {
    $username = if ([string]::IsNullOrWhiteSpace($env:USERNAME)) { 'unknown-user' } else { $env:USERNAME }
    $runRoot = Join-Path $env:TEMP "$username/traderx"
  }
  else {
    $userName = if ([string]::IsNullOrWhiteSpace($env:USER)) { 'unknown-user' } else { $env:USER }
    $runRoot = "/var/tmp/$userName/traderx"
  }
}
$runDir = Join-Path $runRoot 'state-003-agentic-harness-foundation'

New-Item -ItemType Directory -Path (Join-Path $runDir 'logs') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runDir 'pids') -Force | Out-Null
if (-not (Test-Path -LiteralPath $edgeTargetDir)) {
  Copy-Item -LiteralPath $edgeComponentDir -Destination $edgeTargetDir -Recurse -Force
}

if ($BuildOnly) {
  if (Test-Path -LiteralPath (Join-Path $edgeTargetDir 'node_modules') -PathType Container) {
    Write-Host '[build-skip] edge-proxy: already built'
  }
  elseif ($DryRun) {
    Write-Host "[dry-run] [build] edge-proxy: cd $edgeTargetDir && npm install"
  }
  else {
    Write-Host '[build] edge-proxy: npm install'
    Invoke-LoggedCommand -WorkDir $edgeTargetDir -Command 'npm install' -Label '[build] edge-proxy'
  }

  if ($DryRun) {
    Write-Host '[done] dry run complete for state 003'
  }
  else {
    Write-Host '[done] build phase complete for state 003'
    Write-Host '[hint] run without -BuildOnly to start services'
  }
  exit 0
}

if (-not (Test-Path -LiteralPath (Join-Path $edgeTargetDir 'node_modules') -PathType Container)) {
  Write-Host '[error] edge-proxy build artifacts missing (node_modules).'
  Write-Host '[hint] run ./scripts/start-state-003-agentic-harness-foundation-generated.ps1 -BuildOnly'
  exit 1
}

$pidFile = Join-Path (Join-Path $runDir 'pids') 'edge-proxy.pid'
$logFile = Join-Path (Join-Path $runDir 'logs') 'edge-proxy.log'
$oldPid = Read-PidFile -PidFile $pidFile
if ($null -ne $oldPid -and (Test-ProcessAlive -Pid $oldPid)) {
  Write-Host "[skip] edge-proxy already running (pid $oldPid)"
  exit 0
}

if (Test-PortOpen -Port $edgeProxyPort) {
  Write-Host "[error] port :$edgeProxyPort already in use before starting edge-proxy"
  Write-Host '[hint] run ./scripts/stop-state-003-agentic-harness-foundation-generated.ps1 and retry.'
  exit 1
}

if ($DryRun) {
  Write-Host "[dry-run] edge-proxy: cd $edgeTargetDir && npm run start"
  Write-Host '[done] dry run complete for state 003'
  exit 0
}

Write-Host '[start] edge-proxy'
Start-LoggedBackgroundCommand -WorkDir $edgeTargetDir -Command 'npm run start' -LogFile $logFile -PidFile $pidFile

if (Wait-Port -ProcessName 'edge-proxy' -Port $edgeProxyPort -Attempts 60) {
  Write-Host "[ui] http://localhost:$edgeProxyPort"
  Write-Host "[api-explorer] http://localhost:$edgeProxyPort/api/docs"
  exit 0
}

Write-Host "[error] timeout waiting for edge-proxy on :$edgeProxyPort"
Write-Host "[hint] check logs: $logFile"
exit 1
