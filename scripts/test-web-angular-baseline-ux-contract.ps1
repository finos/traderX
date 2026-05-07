#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param([string]$WebRoot)

. "$PSScriptRoot/lib/runtime-common.ps1"

$repoRoot = Get-TraderxRepoRoot -ScriptPath $PSCommandPath
$generatedRoot = Get-TraderxGeneratedRoot -RepoRoot $repoRoot
Use-GeneratedRuntimeScript -ScriptPath $PSCommandPath -GeneratedRoot $generatedRoot -RepoRoot $repoRoot -ScriptArgs $args

if ([string]::IsNullOrWhiteSpace($WebRoot)) {
  $WebRoot = Join-Path $generatedRoot 'code/target-generated/web-front-end/angular'
}

if (-not (Test-Path -LiteralPath $WebRoot -PathType Container)) {
  $altWebRoot = Join-Path $generatedRoot 'code/components/web-front-end-angular-specfirst'
  if (Test-Path -LiteralPath $altWebRoot -PathType Container) {
    $WebRoot = $altWebRoot
  }
}

$altWebRoot = Join-Path $generatedRoot 'code/components/web-front-end-angular-specfirst'
if (Test-Path -LiteralPath $altWebRoot -PathType Container) {
  $aboutTs = Join-Path $WebRoot 'main/app/about/about.component.ts'
  $statusTs = Join-Path $WebRoot 'main/app/status/status.component.ts'
  if (-not (Test-Path -LiteralPath $aboutTs) -or -not (Test-Path -LiteralPath $statusTs)) {
    $WebRoot = $altWebRoot
  }
}

$tradeTs = Join-Path $WebRoot 'main/app/trade/trade.component.ts'
$tradeHtml = Join-Path $WebRoot 'main/app/trade/trade.component.html'
$tradeScss = Join-Path $WebRoot 'main/app/trade/trade.component.scss'
$tradeTicketTs = Join-Path $WebRoot 'main/app/trade/trade-ticket/trade-ticket.component.ts'
$tradeTicketHtml = Join-Path $WebRoot 'main/app/trade/trade-ticket/trade-ticket.component.html'
$tradeBlotterTs = Join-Path $WebRoot 'main/app/trade/trade-blotter/trade-blotter.component.ts'
$positionBlotterTs = Join-Path $WebRoot 'main/app/trade/position-blotter/position-blotter.component.ts'
$accountTs = Join-Path $WebRoot 'main/app/accounts/account.component.ts'
$routingTs = Join-Path $WebRoot 'main/app/routing.ts'
$headerTs = Join-Path $WebRoot 'main/app/header/header.component.ts'
$headerHtml = Join-Path $WebRoot 'main/app/header/header.component.html'
$aboutHtml = Join-Path $WebRoot 'main/app/about/about.component.html'
$statusTs = Join-Path $WebRoot 'main/app/status/status.component.ts'
$statusHtml = Join-Path $WebRoot 'main/app/status/status.component.html'
$stateUiJson = Join-Path $WebRoot 'main/assets/state-ui.json'

function Require-Pattern {
  param(
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
    throw "[error] missing expected source file: $File"
  }

  if (-not (Select-String -LiteralPath $File -Pattern $Pattern -Quiet)) {
    throw "[error] $Message`n        file=$File"
  }
}

Write-Host '[check] all-accounts mode contract in trade page'
Require-Pattern -File $tradeTs -Pattern "displayName: 'All Accounts'" -Message 'expected explicit All Accounts option'
Require-Pattern -File $tradeTs -Pattern 'id: 0' -Message 'expected All Accounts sentinel id=0'
Require-Pattern -File $tradeHtml -Pattern '\[disabled\]="isAllAccountsSelected"' -Message 'expected trade ticket button disabled in all-accounts mode'
Require-Pattern -File $tradeHtml -Pattern 'disabled in <strong>All Accounts</strong> mode\.' -Message 'expected all-accounts explanatory message'
Require-Pattern -File $tradeHtml -Pattern '\[allAccountsMode\]="isAllAccountsSelected"' -Message 'expected allAccountsMode input binding for blotters'
Require-Pattern -File $tradeHtml -Pattern '\[accountIds\]="accountIds"' -Message 'expected accountIds input binding for blotters'

Write-Host '[check] all-accounts aggregation contract in blotters'
Require-Pattern -File $tradeBlotterTs -Pattern '@Input\(\) allAccountsMode = false;' -Message 'expected trade blotter all-accounts input'
Require-Pattern -File $tradeBlotterTs -Pattern 'getAllTrades\(' -Message 'expected trade blotter all-accounts data fetch'
Require-Pattern -File $tradeBlotterTs -Pattern "headerName: 'ACCOUNT'" -Message 'expected account column in all-accounts trade blotter mode'
Require-Pattern -File $positionBlotterTs -Pattern '@Input\(\) allAccountsMode = false;' -Message 'expected position blotter all-accounts input'
Require-Pattern -File $positionBlotterTs -Pattern 'getAllPositions\(' -Message 'expected position blotter all-accounts data fetch'
Require-Pattern -File $positionBlotterTs -Pattern 'mergePositionsBySecurity\(' -Message 'expected cross-account position merge'

Write-Host '[check] security typeahead contract'
Require-Pattern -File $tradeTicketTs -Pattern 'matchLabel' -Message 'expected synthesized ticker-company match label'
Require-Pattern -File $tradeTicketTs -Pattern 'return `\$\{stock\.ticker\} - \$\{stock\.companyName\}`;' -Message 'expected ticker-company combined match label'
Require-Pattern -File $tradeTicketHtml -Pattern 'typeaheadOptionField="matchLabel"' -Message 'expected typeahead to use match label'
Require-Pattern -File $tradeTicketHtml -Pattern 'autocomplete="off"' -Message 'expected browser autocomplete disabled on security input'

Write-Host '[check] account user full-name enrichment contract'
Require-Pattern -File $accountTs -Pattern "field: 'fullName'" -Message 'expected account users grid to display full name'
Require-Pattern -File $accountTs -Pattern 'this\.userService\.getUser\(accountUser\.username\)' -Message 'expected people-service lookup for account-user display'

Write-Host '[check] responsive blotter layout contract'
Require-Pattern -File $tradeScss -Pattern 'flex-wrap: wrap;' -Message 'expected wrapping blotter layout'
Require-Pattern -File $tradeScss -Pattern 'min-width: 700px;' -Message 'expected minimum blotter width guardrail'

Write-Host '[check] state-aware header + about/status routing contract'
Require-Pattern -File $headerTs -Pattern 'TraderX Sample Trading App' -Message 'expected state-aware title formatter in header component'
Require-Pattern -File $headerHtml -Pattern 'class="system-group"' -Message 'expected right-aligned system group in top bar'
Require-Pattern -File $headerTs -Pattern 'isSystemMenuOpen' -Message 'expected internal System dropdown state in header component'
Require-Pattern -File $headerHtml -Pattern '\(click\)="toggleSystemMenu\(\$event\)"' -Message 'expected Angular-driven System dropdown toggle'
Require-Pattern -File $headerHtml -Pattern '\[href\]="metadata\.apiExplorerUrl"' -Message 'expected API explorer link in System dropdown'
Require-Pattern -File $headerHtml -Pattern '\[href\]="metadata\.pubSubInspectorUrl"' -Message 'expected Pub/Sub inspector link in System dropdown'
Require-Pattern -File $headerHtml -Pattern 'routerLink="/about"' -Message 'expected About link in System dropdown'
Require-Pattern -File $headerHtml -Pattern 'routerLink="/status"' -Message 'expected Status link in System dropdown'
Require-Pattern -File $headerHtml -Pattern 'class="finos-logo"' -Message 'expected FINOS logo anchored at right side'
Require-Pattern -File $headerHtml -Pattern 'class="[^"]*nav[^"]*nav-tabs[^"]*functional-tabs[^"]*"' -Message 'expected separate functional tab row'
Require-Pattern -File $routingTs -Pattern "path: 'about'" -Message 'expected about route registration'
Require-Pattern -File $routingTs -Pattern "path: 'status'" -Message 'expected status route registration'
Require-Pattern -File $aboutHtml -Pattern 'Open lineage map' -Message 'expected lineage link in about page'
Require-Pattern -File $aboutHtml -Pattern 'Open API explorer|Open API Explorer|Open API explorer' -Message 'expected API explorer link in about page'
Require-Pattern -File $aboutHtml -Pattern 'Open Pub/Sub inspector|Open Pub/Sub Inspector|Open Pub/Sub inspector' -Message 'expected Pub/Sub inspector link in about page'
Require-Pattern -File $statusTs -Pattern 'statusChecks' -Message 'expected status checks metadata wiring'
Require-Pattern -File $statusHtml -Pattern 'Service Status' -Message 'expected status page heading'

Write-Host '[check] generated UI metadata contract'
if (-not (Test-Path -LiteralPath $stateUiJson -PathType Leaf)) {
  throw "[error] missing generated UI metadata file: $stateUiJson"
}

try {
  $metadata = Get-Content -LiteralPath $stateUiJson -Raw | ConvertFrom-Json -ErrorAction Stop
  foreach ($field in @('stateId', 'generatedAtUtc', 'sourceBranch', 'apiExplorerUrl', 'pubSubInspectorUrl')) {
    if ([string]::IsNullOrWhiteSpace([string]$metadata.$field)) {
      throw "[error] UI metadata missing required field: $field"
    }
  }
}
catch {
  Require-Pattern -File $stateUiJson -Pattern '"stateId"' -Message 'expected stateId in ui metadata'
  Require-Pattern -File $stateUiJson -Pattern '"generatedAtUtc"' -Message 'expected generatedAtUtc in ui metadata'
  Require-Pattern -File $stateUiJson -Pattern '"sourceBranch"' -Message 'expected sourceBranch in ui metadata'
  Require-Pattern -File $stateUiJson -Pattern '"apiExplorerUrl"' -Message 'expected apiExplorerUrl in ui metadata'
  Require-Pattern -File $stateUiJson -Pattern '"pubSubInspectorUrl"' -Message 'expected pubSubInspectorUrl in ui metadata'
}

Write-Host '[done] web-front-end-angular baseline UX contract checks passed'
