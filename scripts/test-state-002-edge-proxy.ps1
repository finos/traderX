#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param([string]$EdgeUrl = 'http://localhost:18080')

. "$PSScriptRoot/lib/runtime-common.ps1"
. "$PSScriptRoot/lib/generated-state-detection.ps1"

$repoRoot = Get-TraderxRepoRoot -ScriptPath $PSCommandPath
$generatedRoot = Get-TraderxGeneratedRoot -RepoRoot $repoRoot
Use-GeneratedRuntimeScript -ScriptPath $PSCommandPath -GeneratedRoot $generatedRoot -RepoRoot $repoRoot -ScriptArgs $args

$expectedState = '002-edge-proxy-uncontainerized'

Write-Host '[check] generated output state metadata'
$status = Report-GeneratedState -ExpectedState $expectedState -GeneratedRoot $generatedRoot
if ($status -ne 0) {
  Write-Host "[error] generated output does not match expected state $expectedState"
  exit 1
}

$httpClient = [System.Net.Http.HttpClient]::new()
try {
  Write-Host '[check] edge-proxy health endpoint'
  $health = $httpClient.GetAsync("$EdgeUrl/health").GetAwaiter().GetResult()
  Write-Host ("HTTP {0}" -f [int]$health.StatusCode)

  Write-Host '[check] proxied UI root'
  $ui = $httpClient.GetAsync("$EdgeUrl/").GetAwaiter().GetResult()
  Write-Host ("HTTP {0}" -f [int]$ui.StatusCode)

  Write-Host '[check] proxied account-service endpoint'
  $account = $httpClient.GetAsync("$EdgeUrl/account-service/account/22214").GetAwaiter().GetResult()
  Write-Host ("HTTP {0}" -f [int]$account.StatusCode)
  if ([int]$account.StatusCode -ne 200) {
    throw "[error] expected 200 from proxied account-service endpoint"
  }

  Write-Host '[check] proxied reference-data endpoint'
  $stocks = $httpClient.GetAsync("$EdgeUrl/reference-data/stocks").GetAwaiter().GetResult()
  Write-Host ("HTTP {0}" -f [int]$stocks.StatusCode)
  if ([int]$stocks.StatusCode -ne 200) {
    throw "[error] expected 200 from proxied reference-data endpoint"
  }

  Write-Host '[check] proxied trade-service unknown ticker validation'
  $payload = '{"security":"NOTREAL","quantity":1,"accountId":22214,"side":"Buy"}'
  $content = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
  $trade = $httpClient.PostAsync("$EdgeUrl/trade-service/trade", $content).GetAwaiter().GetResult()
  $tradeBody = $trade.Content.ReadAsStringAsync().GetAwaiter().GetResult()
  Write-Host $tradeBody
  if ([int]$trade.StatusCode -ne 404) {
    throw "[error] expected 404 for unknown ticker via edge proxy, got $([int]$trade.StatusCode)"
  }
}
finally {
  $httpClient.Dispose()
}

Write-Host '[check] web-front-end state-aware UX contract'
& (Join-Path $repoRoot 'scripts/test-web-angular-baseline-ux-contract.ps1') (Join-Path $generatedRoot 'code/target-generated/web-front-end/angular')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host '[done] state 002 edge-proxy smoke tests passed'
