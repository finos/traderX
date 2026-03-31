#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${1:-generated/code/target-generated/web-front-end/angular}"
if [[ ! -d "${WEB_ROOT}" ]]; then
  ALT_WEB_ROOT="generated/code/components/web-front-end-angular-specfirst"
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
require_pattern "${TRADE_HTML}" "Trade ticket is disabled in <strong>All Accounts</strong> mode\\." "expected all-accounts explanatory message"
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

echo "[done] web-front-end-angular baseline UX contract checks passed"
