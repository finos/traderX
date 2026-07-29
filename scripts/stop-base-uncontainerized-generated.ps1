#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/runtime-common.ps1"

$repoRoot = Get-TraderxRepoRoot -ScriptPath $PSCommandPath
$generatedRoot = Get-TraderxGeneratedRoot -RepoRoot $repoRoot
Use-GeneratedRuntimeScript -ScriptPath $PSCommandPath -GeneratedRoot $generatedRoot -RepoRoot $repoRoot -ScriptArgs $args

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
$runDir = Join-Path $runRoot 'base-uncontainerized'

$processes = @(
  @{ Order = 9; Name = 'web-front-end-angular'; Port = 18093 },
  @{ Order = 8; Name = 'trade-service'; Port = 18092 },
  @{ Order = 7; Name = 'trade-processor'; Port = 18091 },
  @{ Order = 6; Name = 'position-service'; Port = 18090 },
  @{ Order = 5; Name = 'account-service'; Port = 18088 },
  @{ Order = 4; Name = 'people-service'; Port = 18089 },
  @{ Order = 3; Name = 'trade-feed'; Port = 18086 },
  @{ Order = 2; Name = 'reference-data'; Port = 18085 },
  @{ Order = 1; Name = 'database'; Port = 18082 }
)

$pidsDir = Join-Path $runDir 'pids'
if (-not (Test-Path -LiteralPath $pidsDir)) {
  Write-Host "[info] no pid directory at $pidsDir"
  New-Item -ItemType Directory -Path $pidsDir -Force | Out-Null
}

foreach ($proc in $processes | Sort-Object Order -Descending) {
  $pidFile = Join-Path $pidsDir "$($proc.Name).pid"
  $pid = Read-PidFile -PidFile $pidFile
  if ($null -ne $pid) {
    if (Test-ProcessAlive -Pid $pid) {
      Write-Host "[stop] $($proc.Name) (pid $pid)"
      Stop-Process -Id $pid -ErrorAction SilentlyContinue
    }
    else {
      Write-Host "[stale] $($proc.Name) pid file exists but process not running"
    }
    Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
  }

  $listenerPids = @(Get-PortListenerPids -Port $proc.Port)
  foreach ($listenerPid in $listenerPids) {
    if (Test-ProcessAlive -Pid $listenerPid) {
      Write-Host "[stop-port] $($proc.Name) listener on :$($proc.Port) (pid $listenerPid)"
      Stop-Process -Id $listenerPid -ErrorAction SilentlyContinue
    }
  }
}

Write-Host '[done] stop sequence complete'
