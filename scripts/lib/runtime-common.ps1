Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-DefaultEnv {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Value
  )

  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Name))) {
    [Environment]::SetEnvironmentVariable($Name, $Value)
  }
}

function Get-TraderxRepoRoot {
  param([Parameter(Mandatory = $true)][string]$ScriptPath)
  return (Resolve-Path (Join-Path (Split-Path -Parent $ScriptPath) '..')).Path
}

function Get-TraderxGeneratedRoot {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)
  $generatedRoot = [Environment]::GetEnvironmentVariable('TRADERX_GENERATED_ROOT')
  if ([string]::IsNullOrWhiteSpace($generatedRoot)) {
    return (Join-Path $RepoRoot 'generated')
  }
  return $generatedRoot
}

function Use-GeneratedRuntimeScript {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$GeneratedRoot,
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string[]]$ScriptArgs,
    [hashtable]$AdditionalEnv = @{}
  )

  if ([Environment]::GetEnvironmentVariable('TRADERX_LOCAL_RUNTIME_SCRIPT') -eq '1') {
    return
  }

  $scriptName = Split-Path -Leaf $ScriptPath
  $localScript = Join-Path $GeneratedRoot (Join-Path 'code/target-generated/scripts' $scriptName)
  if (-not (Test-Path -LiteralPath $localScript)) {
    return
  }

  $prior = @{}
  $envVars = @{ 
    TRADERX_LOCAL_RUNTIME_SCRIPT = '1'
    TRADERX_GENERATED_ROOT = $GeneratedRoot
    TRADERX_SOURCE_REPO_ROOT = $RepoRoot
  }

  foreach ($k in $AdditionalEnv.Keys) {
    $envVars[$k] = [string]$AdditionalEnv[$k]
  }

  foreach ($k in $envVars.Keys) {
    $prior[$k] = [Environment]::GetEnvironmentVariable($k)
    [Environment]::SetEnvironmentVariable($k, $envVars[$k])
  }

  try {
    & $localScript @ScriptArgs
    exit $LASTEXITCODE
  }
  finally {
    foreach ($k in $envVars.Keys) {
      [Environment]::SetEnvironmentVariable($k, $prior[$k])
    }
  }
}

function Write-Utf8NoBomFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )

  $dir = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }

  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Test-PortOpen {
  param([Parameter(Mandatory = $true)][int]$Port)

  $tcp = [System.Net.Sockets.TcpClient]::new()
  try {
    $asyncResult = $tcp.BeginConnect('127.0.0.1', $Port, $null, $null)
    if (-not $asyncResult.AsyncWaitHandle.WaitOne(200)) {
      return $false
    }
    $tcp.EndConnect($asyncResult)
    return $true
  }
  catch {
    return $false
  }
  finally {
    $tcp.Dispose()
  }
}

function Wait-Port {
  param(
    [Parameter(Mandatory = $true)][string]$ProcessName,
    [Parameter(Mandatory = $true)][int]$Port,
    [int]$Attempts = 120,
    [int]$SleepSeconds = 1
  )

  for ($i = 1; $i -le $Attempts; $i++) {
    if (Test-PortOpen -Port $Port) {
      Write-Host "[ready] $ProcessName on :$Port"
      return $true
    }
    Start-Sleep -Seconds $SleepSeconds
  }

  Write-Host "[error] timeout waiting for $ProcessName on :$Port"
  return $false
}

function Test-ProcessAlive {
  param([Parameter(Mandatory = $true)][int]$Pid)

  try {
    $null = Get-Process -Id $Pid -ErrorAction Stop
    return $true
  }
  catch {
    return $false
  }
}

function Get-PortListenerPids {
  param([Parameter(Mandatory = $true)][int]$Port)

  if ($IsWindows) {
    try {
      return @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop | Select-Object -ExpandProperty OwningProcess -Unique)
    }
    catch {
      return @()
    }
  }

  if (Get-Command lsof -ErrorAction SilentlyContinue) {
    $raw = & lsof -nP -tiTCP:$Port -sTCP:LISTEN 2>$null
    if ($LASTEXITCODE -eq 0 -or -not [string]::IsNullOrWhiteSpace(($raw -join ''))) {
      return @($raw | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
    }
  }

  return @()
}

function Invoke-LoggedCommand {
  param(
    [Parameter(Mandatory = $true)][string]$WorkDir,
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string]$Label,
    [switch]$DryRun
  )

  if ($DryRun) {
    Write-Host "[dry-run] ${Label}: cd $WorkDir && $Command"
    return
  }

  Push-Location $WorkDir
  try {
    & pwsh -NoProfile -Command $Command
    if ($LASTEXITCODE -ne 0) {
      throw "command failed ($LASTEXITCODE)"
    }
  }
  finally {
    Pop-Location
  }
}

function Start-LoggedBackgroundCommand {
  param(
    [Parameter(Mandatory = $true)][string]$WorkDir,
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string]$LogFile,
    [Parameter(Mandatory = $true)][string]$PidFile
  )

  $escapedWorkDir = $WorkDir.Replace("'", "''")
  $launcher = "`$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest; Set-Location -LiteralPath '$escapedWorkDir'; $Command"
  $proc = Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList @('-NoProfile', '-Command', $launcher) -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile -PassThru
  Write-Utf8NoBomFile -Path $PidFile -Content ("{0}`n" -f $proc.Id)
}

function Read-PidFile {
  param([Parameter(Mandatory = $true)][string]$PidFile)

  if (-not (Test-Path -LiteralPath $PidFile)) {
    return $null
  }

  $raw = (Get-Content -LiteralPath $PidFile -Raw).Trim()
  if ($raw -match '^\d+$') {
    return [int]$raw
  }
  return $null
}

function Ensure-Command {
  param([Parameter(Mandatory = $true)][string]$Command)

  if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
    throw "[error] missing required command: $Command"
  }
}
