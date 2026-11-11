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

$pidFile = Join-Path (Join-Path $runDir 'pids') 'edge-proxy.pid'
$pid = Read-PidFile -PidFile $pidFile
if ($null -ne $pid) {
  if (Test-ProcessAlive -Pid $pid) {
    Write-Host "[stop] edge-proxy (pid $pid)"
    Stop-Process -Id $pid -ErrorAction SilentlyContinue
  }
  Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
}

foreach ($listenerPid in @(Get-PortListenerPids -Port $edgeProxyPort)) {
  if (Test-ProcessAlive -Pid $listenerPid) {
    Write-Host "[stop-port] edge-proxy listener on :$edgeProxyPort (pid $listenerPid)"
    Stop-Process -Id $listenerPid -ErrorAction SilentlyContinue
  }
}

& (Join-Path $repoRoot 'scripts/stop-base-uncontainerized-generated.ps1')
exit $LASTEXITCODE
