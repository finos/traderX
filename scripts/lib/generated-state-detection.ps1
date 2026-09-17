Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-StateOrderNumber {
  param([Parameter(Mandatory = $true)][string]$StateId)

  if ($StateId -match '^([0-9]{3})-') {
    return [int]$Matches[1]
  }

  return $null
}

function Read-GeneratedStateId {
  param([Parameter(Mandatory = $true)][string]$GeneratedRoot)

  $metadataPath = Join-Path $GeneratedRoot 'code/target-generated/ci/state-metadata.json'
  if (-not (Test-Path -LiteralPath $metadataPath)) {
    return $null
  }

  try {
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json -ErrorAction Stop
    if ($metadata.stateId) {
      return [string]$metadata.stateId
    }
  }
  catch {
    # Fall back to regex extraction for malformed JSON.
  }

  $raw = Get-Content -LiteralPath $metadataPath -Raw
  $m = [regex]::Match($raw, '"stateId"\s*:\s*"([^"]+)"')
  if ($m.Success) {
    return $m.Groups[1].Value
  }

  return $null
}

function Report-GeneratedState {
  param(
    [Parameter(Mandatory = $true)][string]$ExpectedState,
    [Parameter(Mandatory = $true)][string]$GeneratedRoot
  )

  $metadataPath = Join-Path $GeneratedRoot 'code/target-generated/ci/state-metadata.json'
  $currentState = Read-GeneratedStateId -GeneratedRoot $GeneratedRoot

  if ([string]::IsNullOrWhiteSpace($currentState)) {
    Write-Host "[warn] unable to detect current generated state (missing/invalid: $metadataPath)"
    Write-Host "[hint] run: bash pipeline/generate-state.sh $ExpectedState"
    return 2
  }

  Write-Host "[info] generated output state: $currentState"

  if ($currentState -eq $ExpectedState) {
    Write-Host "[info] generated output matches expected state: $ExpectedState"
    return 0
  }

  Write-Host "[warn] expected generated state $ExpectedState, found $currentState"

  $expectedNum = Get-StateOrderNumber -StateId $ExpectedState
  $currentNum = Get-StateOrderNumber -StateId $currentState

  if ($null -ne $expectedNum -and $null -ne $currentNum) {
    if ($currentNum -lt $expectedNum) {
      Write-Host '[hint] this is a forward transition (older -> newer). Regeneration is usually safe.'
    }
    elseif ($currentNum -gt $expectedNum) {
      Write-Host '[hint] this is a backward transition (newer -> older). Clean rebuild/regeneration is recommended.'
    }
  }

  Write-Host "[hint] regenerate now: bash pipeline/generate-state.sh $ExpectedState"
  Write-Host '[hint] set TRADERX_REGENERATE_ON_STATE_MISMATCH=1 to auto-regenerate before startup'
  return 3
}

function Ensure-GeneratedState {
  param(
    [Parameter(Mandatory = $true)][string]$ExpectedState,
    [Parameter(Mandatory = $true)][string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$GeneratedRoot
  )

  $status = Report-GeneratedState -ExpectedState $ExpectedState -GeneratedRoot $GeneratedRoot

  if ($status -ne 0 -and [Environment]::GetEnvironmentVariable('TRADERX_REGENERATE_ON_STATE_MISMATCH') -eq '1' -and [Environment]::GetEnvironmentVariable('TRADERX_LOCAL_RUNTIME_SCRIPT') -ne '1') {
    Write-Host "[action] regenerating expected state $ExpectedState"
    $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bashCommand) {
      throw '[error] auto-regeneration requires bash on PATH; install bash or unset TRADERX_REGENERATE_ON_STATE_MISMATCH'
    }
    & $bashCommand.Source (Join-Path $RepoRoot 'pipeline/generate-state.sh') $ExpectedState
    if ($LASTEXITCODE -ne 0) {
      throw '[error] generation failed'
    }
    $status = Report-GeneratedState -ExpectedState $ExpectedState -GeneratedRoot $GeneratedRoot
  }

  if ($status -ne 0 -and [Environment]::GetEnvironmentVariable('TRADERX_STATE_MISMATCH_STRICT') -eq '1') {
    throw '[error] generated state mismatch remains (TRADERX_STATE_MISMATCH_STRICT=1)'
  }
}
