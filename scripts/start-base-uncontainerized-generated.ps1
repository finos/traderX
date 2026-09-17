#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [switch]$DryRun,
  [switch]$BuildOnly
)

. "$PSScriptRoot/lib/runtime-common.ps1"
. "$PSScriptRoot/lib/generated-state-detection.ps1"

$repoRoot = Get-TraderxRepoRoot -ScriptPath $PSCommandPath
$generatedRoot = Get-TraderxGeneratedRoot -RepoRoot $repoRoot
Use-GeneratedRuntimeScript -ScriptPath $PSCommandPath -GeneratedRoot $generatedRoot -RepoRoot $repoRoot -ScriptArgs $args

$target = Join-Path $generatedRoot 'code/target-generated'
$expectedState = if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('TRADERX_EXPECTED_STATE_ID'))) { '001-baseline-uncontainerized-parity' } else { [Environment]::GetEnvironmentVariable('TRADERX_EXPECTED_STATE_ID') }
$sourceRepoRoot = if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('TRADERX_SOURCE_REPO_ROOT'))) { $repoRoot } else { [Environment]::GetEnvironmentVariable('TRADERX_SOURCE_REPO_ROOT') }
$specSource = Join-Path $sourceRepoRoot 'catalog/base-uncontainerized-processes.csv'
$spec = Join-Path $target 'catalog/base-uncontainerized-processes.csv'

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
$toolCacheDir = Join-Path $runDir 'tool-cache'

$referenceDataSpecfirst = Join-Path $generatedRoot 'code/components/reference-data-specfirst'
$databaseSpecfirst = Join-Path $generatedRoot 'code/components/database-specfirst'
$peopleServiceSpecfirst = Join-Path $generatedRoot 'code/components/people-service-specfirst'
$accountServiceSpecfirst = Join-Path $generatedRoot 'code/components/account-service-specfirst'
$positionServiceSpecfirst = Join-Path $generatedRoot 'code/components/position-service-specfirst'
$tradeFeedSpecfirst = Join-Path $generatedRoot 'code/components/trade-feed-specfirst'
$tradeProcessorSpecfirst = Join-Path $generatedRoot 'code/components/trade-processor-specfirst'
$tradeServiceSpecfirst = Join-Path $generatedRoot 'code/components/trade-service-specfirst'
$webFrontEndAngularSpecfirst = Join-Path $generatedRoot 'code/components/web-front-end-angular-specfirst'

Ensure-GeneratedState -ExpectedState $expectedState -RepoRoot $repoRoot -GeneratedRoot $generatedRoot

function Ensure-ComponentLayout {
  param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$TargetDir
  )

  if (Test-Path -LiteralPath $TargetDir) {
    return
  }

  Copy-Item -LiteralPath $SourceDir -Destination $TargetDir -Recurse -Force
}

function Prepare-GeneratedBaseLayout {
  $generatedPaths = @(
    $referenceDataSpecfirst,
    $databaseSpecfirst,
    $peopleServiceSpecfirst,
    $accountServiceSpecfirst,
    $positionServiceSpecfirst,
    $tradeFeedSpecfirst,
    $tradeProcessorSpecfirst,
    $tradeServiceSpecfirst,
    $webFrontEndAngularSpecfirst
  )

  foreach ($p in $generatedPaths) {
    if (-not (Test-Path -LiteralPath $p -PathType Container)) {
      throw "[error] required generated component not found: $p`n[hint] run the root pipeline generation scripts first."
    }
  }

  New-Item -ItemType Directory -Path $target -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $target 'web-front-end') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $target 'catalog') -Force | Out-Null

  if (-not (Test-Path -LiteralPath $specSource -PathType Leaf)) {
    throw "[error] missing startup spec source: $specSource"
  }
  Copy-Item -LiteralPath $specSource -Destination $spec -Force

  Ensure-ComponentLayout -SourceDir $referenceDataSpecfirst -TargetDir (Join-Path $target 'reference-data')
  Ensure-ComponentLayout -SourceDir $databaseSpecfirst -TargetDir (Join-Path $target 'database')
  Ensure-ComponentLayout -SourceDir $peopleServiceSpecfirst -TargetDir (Join-Path $target 'people-service')
  Ensure-ComponentLayout -SourceDir $accountServiceSpecfirst -TargetDir (Join-Path $target 'account-service')
  Ensure-ComponentLayout -SourceDir $positionServiceSpecfirst -TargetDir (Join-Path $target 'position-service')
  Ensure-ComponentLayout -SourceDir $tradeFeedSpecfirst -TargetDir (Join-Path $target 'trade-feed')
  Ensure-ComponentLayout -SourceDir $tradeProcessorSpecfirst -TargetDir (Join-Path $target 'trade-processor')
  Ensure-ComponentLayout -SourceDir $tradeServiceSpecfirst -TargetDir (Join-Path $target 'trade-service')
  Ensure-ComponentLayout -SourceDir $webFrontEndAngularSpecfirst -TargetDir (Join-Path $target 'web-front-end/angular')

  Write-Host "[ok] generated base layout prepared in $target"
}

function Resolve-GradleWrapperCommand {
  param([Parameter(Mandatory = $true)][string]$WorkDir)

  if ($IsWindows) {
    if (-not (Test-Path -LiteralPath (Join-Path $WorkDir 'gradlew.bat'))) {
      throw "[error] missing Gradle wrapper batch script in $WorkDir"
    }
    return '.\\gradlew.bat'
  }

  if (-not (Test-Path -LiteralPath (Join-Path $WorkDir 'gradlew'))) {
    throw "[error] missing Gradle wrapper script in $WorkDir"
  }
  return './gradlew'
}

function Get-JavaServiceJar {
  param([Parameter(Mandatory = $true)][string]$WorkDir)

  $jars = Get-ChildItem -LiteralPath (Join-Path $WorkDir 'build/libs') -Filter '*.jar' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch 'plain' } |
    Sort-Object Name

  if (-not $jars -or $jars.Count -eq 0) {
    return $null
  }

  return $jars[0].FullName
}

function Build-ArtifactExists {
  param(
    [Parameter(Mandatory = $true)][string]$ProcessName,
    [Parameter(Mandatory = $true)][string]$WorkDir
  )

  switch ($ProcessName) {
    'web-front-end-angular' {
      return (Test-Path -LiteralPath (Join-Path $WorkDir 'node_modules') -PathType Container) -and
        (Test-Path -LiteralPath (Join-Path $WorkDir 'dist') -PathType Container)
    }
    'reference-data' { return (Test-Path -LiteralPath (Join-Path $WorkDir 'node_modules') -PathType Container) }
    'trade-feed' { return (Test-Path -LiteralPath (Join-Path $WorkDir 'node_modules') -PathType Container) }
    'people-service' {
      $candidate = Get-ChildItem -LiteralPath (Join-Path $WorkDir 'bin/Debug') -Filter 'PeopleService.WebApi.dll' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
      return $null -ne $candidate
    }
    'database' {
      return Test-Path -LiteralPath (Join-Path $WorkDir 'build/libs/database-specfirst.jar') -PathType Leaf
    }
    'account-service' { return $null -ne (Get-JavaServiceJar -WorkDir $WorkDir) }
    'position-service' { return $null -ne (Get-JavaServiceJar -WorkDir $WorkDir) }
    'trade-processor' { return $null -ne (Get-JavaServiceJar -WorkDir $WorkDir) }
    'trade-service' { return $null -ne (Get-JavaServiceJar -WorkDir $WorkDir) }
    default { return $false }
  }
}

function Invoke-Build {
  param(
    [Parameter(Mandatory = $true)][string]$ProcessName,
    [Parameter(Mandatory = $true)][string]$WorkDir,
    [switch]$DryRunMode
  )

  if (Build-ArtifactExists -ProcessName $ProcessName -WorkDir $WorkDir) {
    Write-Host "[build-skip] $ProcessName`: already built"
    return
  }

  switch ($ProcessName) {
    'reference-data' {
      Invoke-LoggedCommand -WorkDir $WorkDir -Command 'npm install' -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    'trade-feed' {
      Invoke-LoggedCommand -WorkDir $WorkDir -Command 'npm install' -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    'web-front-end-angular' {
      Invoke-LoggedCommand -WorkDir $WorkDir -Command 'npm install' -Label "[build] $ProcessName" -DryRun:$DryRunMode
      Invoke-LoggedCommand -WorkDir $WorkDir -Command 'npm run build' -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    'people-service' {
      Invoke-LoggedCommand -WorkDir $WorkDir -Command 'dotnet build' -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    'database' {
      $gradleCmd = Resolve-GradleWrapperCommand -WorkDir $WorkDir
      Invoke-LoggedCommand -WorkDir $WorkDir -Command "$gradleCmd build -x test" -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    'account-service' {
      $gradleCmd = Resolve-GradleWrapperCommand -WorkDir $WorkDir
      Invoke-LoggedCommand -WorkDir $WorkDir -Command "$gradleCmd build -x test" -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    'position-service' {
      $gradleCmd = Resolve-GradleWrapperCommand -WorkDir $WorkDir
      Invoke-LoggedCommand -WorkDir $WorkDir -Command "$gradleCmd build -x test" -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    'trade-processor' {
      $gradleCmd = Resolve-GradleWrapperCommand -WorkDir $WorkDir
      Invoke-LoggedCommand -WorkDir $WorkDir -Command "$gradleCmd build -x test" -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    'trade-service' {
      $gradleCmd = Resolve-GradleWrapperCommand -WorkDir $WorkDir
      Invoke-LoggedCommand -WorkDir $WorkDir -Command "$gradleCmd build -x test" -Label "[build] $ProcessName" -DryRun:$DryRunMode
      return
    }
    default {
      throw "[error] no build handler for process: $ProcessName"
    }
  }
}

function Resolve-StartCommand {
  param(
    [Parameter(Mandatory = $true)][string]$ProcessName,
    [Parameter(Mandatory = $true)][string]$WorkDir
  )

  switch ($ProcessName) {
    'database' {
      if ($IsWindows) {
        if (-not (Test-Path -LiteralPath (Join-Path $WorkDir 'run.ps1'))) {
          throw "[error] missing database runner: $WorkDir/run.ps1"
        }
        return '& ./run.ps1'
      }
      return './run.sh'
    }
    'reference-data' { return 'npm run start' }
    'trade-feed' { return 'npm run start' }
    'people-service' { return '$env:ASPNETCORE_ENVIRONMENT=''Development''; dotnet ./bin/Debug/net9.0/PeopleService.WebApi.dll' }
    'account-service' {
      $jar = Get-JavaServiceJar -WorkDir $WorkDir
      if (-not $jar) {
        throw "[error] unable to resolve jar for $ProcessName"
      }
      return "java -jar '$jar'"
    }
    'position-service' {
      $jar = Get-JavaServiceJar -WorkDir $WorkDir
      if (-not $jar) {
        throw "[error] unable to resolve jar for $ProcessName"
      }
      return "java -jar '$jar'"
    }
    'trade-processor' {
      $jar = Get-JavaServiceJar -WorkDir $WorkDir
      if (-not $jar) {
        throw "[error] unable to resolve jar for $ProcessName"
      }
      return "java -jar '$jar'"
    }
    'trade-service' {
      $jar = Get-JavaServiceJar -WorkDir $WorkDir
      if (-not $jar) {
        throw "[error] unable to resolve jar for $ProcessName"
      }
      return "java -jar '$jar'"
    }
    'web-front-end-angular' { return 'node serve-angular-dist.js' }
    default { throw "[error] no start handler for process: $ProcessName" }
  }
}

function Preflight-Checks {
  Ensure-Command -Command dotnet

  & dotnet --version *> $null
  if ($LASTEXITCODE -ne 0) {
    throw '[error] dotnet runtime is installed but not runnable on this machine.'
  }

  $dotnetRuntimes = (& dotnet --list-runtimes 2>$null) -join "`n"
  if ($dotnetRuntimes -notmatch '^Microsoft\.NETCore\.App 9\.' -and $dotnetRuntimes -notmatch "`nMicrosoft\.NETCore\.App 9\.") {
    throw '[error] missing required runtime: Microsoft.NETCore.App 9.x (arm64) for people-service (net9.0).'
  }
  if ($dotnetRuntimes -notmatch '^Microsoft\.AspNetCore\.App 9\.' -and $dotnetRuntimes -notmatch "`nMicrosoft\.AspNetCore\.App 9\.") {
    throw '[error] missing required runtime: Microsoft.AspNetCore.App 9.x (arm64) for people-service (net9.0).'
  }

  if ([Environment]::GetEnvironmentVariable('TRADERSPEC_SKIP_NETWORK_CHECK') -eq '1') {
    return
  }

  $gradleDistUrl = if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('GRADLE_WRAPPER_CHECK_URL'))) { 'https://services.gradle.org/distributions/' } else { [Environment]::GetEnvironmentVariable('GRADLE_WRAPPER_CHECK_URL') }
  $mavenRepoUrl = if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('MAVEN_CENTRAL_CHECK_URL'))) { 'https://repo.maven.apache.org/maven2/' } else { [Environment]::GetEnvironmentVariable('MAVEN_CENTRAL_CHECK_URL') }

  foreach ($url in @($gradleDistUrl, $mavenRepoUrl)) {
    try {
      Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 | Out-Null
    }
    catch {
      throw "[error] gradle network preflight failed for $url"
    }
  }
}

Prepare-GeneratedBaseLayout

New-Item -ItemType Directory -Path (Join-Path $runDir 'logs') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runDir 'pids') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $toolCacheDir 'gradle') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $toolCacheDir 'npm') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $toolCacheDir 'dotnet-home') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $toolCacheDir 'nuget') -Force | Out-Null

Set-DefaultEnv -Name 'GRADLE_USER_HOME' -Value (Join-Path $toolCacheDir 'gradle')
Set-DefaultEnv -Name 'npm_config_cache' -Value (Join-Path $toolCacheDir 'npm')
Set-DefaultEnv -Name 'DOTNET_CLI_HOME' -Value (Join-Path $toolCacheDir 'dotnet-home')
Set-DefaultEnv -Name 'NUGET_PACKAGES' -Value (Join-Path $toolCacheDir 'nuget')

Set-DefaultEnv -Name 'DATABASE_TCP_PORT' -Value '18082'
Set-DefaultEnv -Name 'DATABASE_PG_PORT' -Value '18083'
Set-DefaultEnv -Name 'DATABASE_WEB_PORT' -Value '18084'
Set-DefaultEnv -Name 'REFERENCE_DATA_SERVICE_PORT' -Value '18085'
Set-DefaultEnv -Name 'TRADE_FEED_PORT' -Value '18086'
Set-DefaultEnv -Name 'ACCOUNT_SERVICE_PORT' -Value '18088'
Set-DefaultEnv -Name 'PEOPLE_SERVICE_PORT' -Value '18089'
Set-DefaultEnv -Name 'POSITION_SERVICE_PORT' -Value '18090'
Set-DefaultEnv -Name 'TRADE_PROCESSOR_SERVICE_PORT' -Value '18091'
Set-DefaultEnv -Name 'TRADING_SERVICE_PORT' -Value '18092'
Set-DefaultEnv -Name 'WEB_SERVICE_ANGULAR_PORT' -Value '18093'

Set-DefaultEnv -Name 'DATABASE_TCP_HOST' -Value 'localhost'
Set-DefaultEnv -Name 'PEOPLE_SERVICE_HOST' -Value 'localhost'
Set-DefaultEnv -Name 'ACCOUNT_SERVICE_HOST' -Value 'localhost'
Set-DefaultEnv -Name 'REFERENCE_DATA_HOST' -Value 'localhost'
Set-DefaultEnv -Name 'TRADE_FEED_HOST' -Value 'localhost'

$processes = @(
  @{ Order = 1; Name = 'database'; Workdir = 'database'; Port = 18082 },
  @{ Order = 2; Name = 'reference-data'; Workdir = 'reference-data'; Port = 18085 },
  @{ Order = 3; Name = 'trade-feed'; Workdir = 'trade-feed'; Port = 18086 },
  @{ Order = 4; Name = 'people-service'; Workdir = 'people-service/PeopleService.WebApi'; Port = 18089 },
  @{ Order = 5; Name = 'account-service'; Workdir = 'account-service'; Port = 18088 },
  @{ Order = 6; Name = 'position-service'; Workdir = 'position-service'; Port = 18090 },
  @{ Order = 7; Name = 'trade-processor'; Workdir = 'trade-processor'; Port = 18091 },
  @{ Order = 8; Name = 'trade-service'; Workdir = 'trade-service'; Port = 18092 },
  @{ Order = 9; Name = 'web-front-end-angular'; Workdir = 'web-front-end/angular'; Port = 18093 }
)

if (-not (Test-Path -LiteralPath $spec -PathType Leaf)) {
  throw "[error] missing startup spec: $spec"
}

if (-not $DryRun) {
  Preflight-Checks
}

if ($BuildOnly) {
  Write-Host '[build] building base uncontainerized services (--build-only)'
  foreach ($proc in $processes | Sort-Object Order) {
    $workdir = Join-Path $target $proc.Workdir
    if (-not (Test-Path -LiteralPath $workdir -PathType Container)) {
      throw "[error] missing workdir for $($proc.Name): $workdir"
    }
    Invoke-Build -ProcessName $proc.Name -WorkDir $workdir -DryRunMode:$DryRun
  }

  if ($DryRun) {
    Write-Host '[done] dry run complete'
  }
  else {
    Write-Host '[done] build phase complete'
    Write-Host '[hint] run the same script without -BuildOnly to start services'
  }
  exit 0
}

foreach ($proc in $processes | Sort-Object Order) {
  $workdir = Join-Path $target $proc.Workdir
  if (-not (Build-ArtifactExists -ProcessName $proc.Name -WorkDir $workdir)) {
    Write-Host "[error] $($proc.Name): missing build artifacts required by start command."
    Write-Host '[hint] run ./scripts/start-base-uncontainerized-generated.ps1 -BuildOnly'
    exit 1
  }

  $pidFile = Join-Path (Join-Path $runDir 'pids') "$($proc.Name).pid"
  $logFile = Join-Path (Join-Path $runDir 'logs') "$($proc.Name).log"

  $oldPid = Read-PidFile -PidFile $pidFile
  if ($null -ne $oldPid -and (Test-ProcessAlive -Pid $oldPid)) {
    Write-Host "[skip] $($proc.Name) already running (pid $oldPid)"
    continue
  }

  if (Test-PortOpen -Port $proc.Port) {
    Write-Host "[error] port :$($proc.Port) already in use before starting $($proc.Name)"
    $pids = @(Get-PortListenerPids -Port $proc.Port)
    if ($pids.Count -gt 0) {
      Write-Host "[hint] listener pid(s): $($pids -join ', ')"
    }
    Write-Host '[hint] run stop script, then retry:'
    Write-Host '       ./scripts/stop-base-uncontainerized-generated.ps1'
    exit 1
  }

  $startCommand = Resolve-StartCommand -ProcessName $proc.Name -WorkDir $workdir

  if ($DryRun) {
    Write-Host "[dry-run] $($proc.Name): cd $workdir && $startCommand"
    continue
  }

  Write-Host "[start] $($proc.Name)"
  Start-LoggedBackgroundCommand -WorkDir $workdir -Command $startCommand -LogFile $logFile -PidFile $pidFile

  if (-not (Wait-Port -ProcessName $proc.Name -Port $proc.Port)) {
    Write-Host "[hint] check logs: $logFile"
    exit 1
  }
}

if ($DryRun) {
  Write-Host '[done] dry run complete'
}
else {
  Write-Host '[done] base uncontainerized generated stack started'
  Write-Host "[ui] http://localhost:$($env:WEB_SERVICE_ANGULAR_PORT)"
}
