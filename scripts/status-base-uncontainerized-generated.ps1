#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/runtime-common.ps1"
. "$PSScriptRoot/lib/generated-state-detection.ps1"

$repoRoot = Get-TraderxRepoRoot -ScriptPath $PSCommandPath
$generatedRoot = Get-TraderxGeneratedRoot -RepoRoot $repoRoot
Use-GeneratedRuntimeScript -ScriptPath $PSCommandPath -GeneratedRoot $generatedRoot -RepoRoot $repoRoot -ScriptArgs $args

$currentGeneratedState = Read-GeneratedStateId -GeneratedRoot $generatedRoot
if ([string]::IsNullOrWhiteSpace($currentGeneratedState)) {
  Write-Host '[warn] generated output state is unknown (missing ci/state-metadata.json)'
}
else {
  Write-Host "[info] generated output state: $currentGeneratedState"
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
$runDir = Join-Path $runRoot 'base-uncontainerized'

$processes = @(
  @{ Name = 'database'; Port = 18082 },
  @{ Name = 'reference-data'; Port = 18085 },
  @{ Name = 'trade-feed'; Port = 18086 },
  @{ Name = 'people-service'; Port = 18089 },
  @{ Name = 'account-service'; Port = 18088 },
  @{ Name = 'position-service'; Port = 18090 },
  @{ Name = 'trade-processor'; Port = 18091 },
  @{ Name = 'trade-service'; Port = 18092 },
  @{ Name = 'web-front-end-angular'; Port = 18093 }
)

"{0,-24} {1,-10} {2,-8} {3,-12}" -f 'process', 'pid', 'running', 'port-open'
"{0,-24} {1,-10} {2,-8} {3,-12}" -f '------------------------', '----------', '--------', '------------'

foreach ($proc in $processes) {
  $pidFile = Join-Path (Join-Path $runDir 'pids') "$($proc.Name).pid"
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

  if (Test-PortOpen -Port $proc.Port) {
    $portOpen = 'yes'
  }

  "{0,-24} {1,-10} {2,-8} {3,-12}" -f $proc.Name, $pid, $running, $portOpen
}
