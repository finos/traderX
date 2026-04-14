#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi
WEB_ROOT="${1:-${GENERATED_ROOT}/code/target-generated/web-front-end/angular}"
if [[ ! -d "${WEB_ROOT}" ]]; then
  ALT_WEB_ROOT="${GENERATED_ROOT}/code/components/web-front-end-angular-specfirst"
  if [[ -d "${ALT_WEB_ROOT}" ]]; then
    WEB_ROOT="${ALT_WEB_ROOT}"
  fi
fi
TRADE_TS="${WEB_ROOT}/main/app/trade/trade.component.ts"
TRADE_HTML="${WEB_ROOT}/main/app/trade/trade.component.html"
TRADE_SCSS="${WEB_ROOT}/main/app/trade/trade.component.scss"
TRADE_TICKET_TS="${WEB_ROOT}/main/app/trade/trade-ticket/trade-ticket.component.ts"
TRADE_TICKET_HTML="${WEB_ROOT}/main/app/trade/trade-ticket/trade-ticket.component.html"
TRADE_BLOTTER_TS="${WEB_ROOT}/main/app/trade/trade-blotter/trade-blotter.component.ts"
POSITION_BLOTTER_TS="${WEB_ROOT}/main/app/trade/position-blotter/position-blotter.component.ts"
ACCOUNT_TS="${WEB_ROOT}/main/app/accounts/account.component.ts"
ROUTING_TS="${WEB_ROOT}/main/app/routing.ts"
HEADER_TS="${WEB_ROOT}/main/app/header/header.component.ts"
HEADER_HTML="${WEB_ROOT}/main/app/header/header.component.html"
ABOUT_TS="${WEB_ROOT}/main/app/about/about.component.ts"
ABOUT_HTML="${WEB_ROOT}/main/app/about/about.component.html"
STATUS_TS="${WEB_ROOT}/main/app/status/status.component.ts"
STATUS_HTML="${WEB_ROOT}/main/app/status/status.component.html"
STATE_UI_JSON="${WEB_ROOT}/main/assets/state-ui.json"

require_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if [[ ! -f "${file}" ]]; then
    echo "[error] missing expected source file: ${file}"
    exit 1
  fi
  if ! grep -Eq "${pattern}" "${file}"; then
    echo "[error] ${message}"
    echo "        file=${file}"
    exit 1
  fi
}

echo "[check] all-accounts mode contract in trade page"
require_pattern "${TRADE_TS}" "displayName: 'All Accounts'" "expected explicit All Accounts option"
require_pattern "${TRADE_TS}" "id: 0" "expected All Accounts sentinel id=0"
require_pattern "${TRADE_HTML}" "\\[disabled\\]=\"isAllAccountsSelected\"" "expected trade ticket button disabled in all-accounts mode"
require_pattern "${TRADE_HTML}" "disabled in <strong>All Accounts</strong> mode\\." "expected all-accounts explanatory message"
require_pattern "${TRADE_HTML}" "\\[allAccountsMode\\]=\"isAllAccountsSelected\"" "expected allAccountsMode input binding for blotters"
require_pattern "${TRADE_HTML}" "\\[accountIds\\]=\"accountIds\"" "expected accountIds input binding for blotters"

echo "[check] all-accounts aggregation contract in blotters"
require_pattern "${TRADE_BLOTTER_TS}" "@Input\\(\\) allAccountsMode = false;" "expected trade blotter all-accounts input"
require_pattern "${TRADE_BLOTTER_TS}" "getAllTrades\\(" "expected trade blotter all-accounts data fetch"
require_pattern "${TRADE_BLOTTER_TS}" "headerName: 'ACCOUNT'" "expected account column in all-accounts trade blotter mode"
require_pattern "${POSITION_BLOTTER_TS}" "@Input\\(\\) allAccountsMode = false;" "expected position blotter all-accounts input"
require_pattern "${POSITION_BLOTTER_TS}" "getAllPositions\\(" "expected position blotter all-accounts data fetch"
require_pattern "${POSITION_BLOTTER_TS}" "mergePositionsBySecurity\\(" "expected cross-account position merge"

echo "[check] security typeahead contract"
require_pattern "${TRADE_TICKET_TS}" "matchLabel" "expected synthesized ticker-company match label"
require_pattern "${TRADE_TICKET_TS}" 'return `\$\{stock\.ticker\} - \$\{stock\.companyName\}`;' "expected ticker-company combined match label"
require_pattern "${TRADE_TICKET_HTML}" "typeaheadOptionField=\"matchLabel\"" "expected typeahead to use match label"
require_pattern "${TRADE_TICKET_HTML}" "autocomplete=\"off\"" "expected browser autocomplete disabled on security input"

echo "[check] account user full-name enrichment contract"
require_pattern "${ACCOUNT_TS}" "field: 'fullName'" "expected account users grid to display full name"
require_pattern "${ACCOUNT_TS}" "this\\.userService\\.getUser\\(accountUser\\.username\\)" "expected people-service lookup for account-user display"

echo "[check] responsive blotter layout contract"
require_pattern "${TRADE_SCSS}" "flex-wrap: wrap;" "expected wrapping blotter layout"
require_pattern "${TRADE_SCSS}" "min-width: 700px;" "expected minimum blotter width guardrail"

echo "[check] state-aware header + about/status routing contract"
require_pattern "${HEADER_TS}" "TraderX Sample Trading App" "expected state-aware title formatter in header component"
require_pattern "${HEADER_HTML}" "class=\"system-group\"" "expected right-aligned system group in top bar"
require_pattern "${HEADER_TS}" "isSystemMenuOpen" "expected internal System dropdown state in header component"
require_pattern "${HEADER_HTML}" '\(click\)="toggleSystemMenu\(\$event\)"' "expected Angular-driven System dropdown toggle"
require_pattern "${HEADER_HTML}" "\\[href\\]=\"metadata\\.apiExplorerUrl\"" "expected API explorer link in System dropdown"
require_pattern "${HEADER_HTML}" "routerLink=\"/about\"" "expected About link in System dropdown"
require_pattern "${HEADER_HTML}" "routerLink=\"/status\"" "expected Status link in System dropdown"
require_pattern "${HEADER_HTML}" "class=\"finos-logo\"" "expected FINOS logo anchored at right side"
require_pattern "${HEADER_HTML}" "class=\"nav nav-tabs mt-3 functional-tabs\"" "expected separate functional tab row"
require_pattern "${ROUTING_TS}" "path: 'about'" "expected about route registration"
require_pattern "${ROUTING_TS}" "path: 'status'" "expected status route registration"
require_pattern "${ABOUT_HTML}" "Open lineage map" "expected lineage link in about page"
require_pattern "${ABOUT_HTML}" "Open API explorer|Open API Explorer|Open API explorer" "expected API explorer link in about page"
require_pattern "${STATUS_TS}" "statusChecks" "expected status checks metadata wiring"
require_pattern "${STATUS_HTML}" "Service Status" "expected status page heading"

echo "[check] generated UI metadata contract"
if [[ ! -f "${STATE_UI_JSON}" ]]; then
  echo "[error] missing generated UI metadata file: ${STATE_UI_JSON}"
  exit 1
fi
if command -v jq >/dev/null 2>&1; then
  state_id="$(jq -r '.stateId // empty' "${STATE_UI_JSON}")"
  generated_at="$(jq -r '.generatedAtUtc // empty' "${STATE_UI_JSON}")"
  source_branch="$(jq -r '.sourceBranch // empty' "${STATE_UI_JSON}")"
  if [[ -z "${state_id}" || -z "${generated_at}" || -z "${source_branch}" ]]; then
    echo "[error] UI metadata missing required fields (stateId/generatedAtUtc/sourceBranch)"
    exit 1
  fi
else
  require_pattern "${STATE_UI_JSON}" "\"stateId\"" "expected stateId in ui metadata"
  require_pattern "${STATE_UI_JSON}" "\"generatedAtUtc\"" "expected generatedAtUtc in ui metadata"
  require_pattern "${STATE_UI_JSON}" "\"sourceBranch\"" "expected sourceBranch in ui metadata"
fi

echo "[done] web-front-end-angular baseline UX contract checks passed"
