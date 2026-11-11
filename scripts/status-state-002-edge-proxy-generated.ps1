#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/runtime-common.ps1"

$repoRoot = Get-TraderxRepoRoot -ScriptPath $PSCommandPath
$generatedRoot = Get-TraderxGeneratedRoot -RepoRoot $repoRoot
Use-GeneratedRuntimeScript -ScriptPath $PSCommandPath -GeneratedRoot $generatedRoot -RepoRoot $repoRoot -ScriptArgs $args

$edgeProxyPort = if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('EDGE_PROXY_PORT'))) { 18080 } else { [int][Environment]::GetEnvironmentVariable('EDGE_PROXY_PORT') }
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
$runDir = Join-Path $runRoot 'state-002-edge-proxy'

& (Join-Path $repoRoot 'scripts/status-base-uncontainerized-generated.ps1')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$pidFile = Join-Path (Join-Path $runDir 'pids') 'edge-proxy.pid'
$pid = '-'
$running = 'no'
$portOpen = 'no'

$savedPid = Read-PidFile -PidFile $pidFile
if ($null -ne $savedPid) {
  $pid = [string]$savedPid
  if (Test-ProcessAlive -Pid $savedPid) {
    $running = 'yes'
  }
}

if (Test-PortOpen -Port $edgeProxyPort) {
  $portOpen = 'yes'
}

"{0,-24} {1,-10} {2,-8} {3,-12}" -f 'edge-proxy', $pid, $running, $portOpen
