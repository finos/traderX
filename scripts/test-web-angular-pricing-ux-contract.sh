#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"
WEB_ROOT="${1:-${GENERATED_ROOT}/code/target-generated/web-front-end/angular}"
EXPECT_ORDER_UI=0

shift || true
while (( "$#" )); do
  case "$1" in
    --orders)
      EXPECT_ORDER_UI=1
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] usage: $0 [WEB_ROOT] [--orders]"
      exit 1
      ;;
  esac
  shift
done

TRADE_TS="${WEB_ROOT}/main/app/trade/trade.component.ts"
TRADE_HTML="${WEB_ROOT}/main/app/trade/trade.component.html"
POSITION_BLOTTER_TS="${WEB_ROOT}/main/app/trade/position-blotter/position-blotter.component.ts"
HEADER_HTML="${WEB_ROOT}/main/app/header/header.component.html"
ROUTING_TS="${WEB_ROOT}/main/app/routing.ts"
ADMIN_TS="${WEB_ROOT}/main/app/admin/order-admin.component.ts"
ADMIN_HTML="${WEB_ROOT}/main/app/admin/order-admin.component.html"

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

echo "[check] pricing-aware trade page summary contract"
require_pattern "${TRADE_TS}" "PortfolioSummary" "expected trade component to retain portfolio summary model"
require_pattern "${TRADE_TS}" "PositionService" "expected trade component to load all positions for total portfolio summaries"
require_pattern "${TRADE_TS}" "TradeFeedService" "expected trade component to subscribe to pricing stream"
require_pattern "${TRADE_TS}" "subscribe\\('pricing\\.\\*'" "expected trade component pricing wildcard subscription"
require_pattern "${TRADE_TS}" "loadAllPositions\\(" "expected all-accounts position bootstrap for summary cards"
require_pattern "${TRADE_TS}" "recomputeAllAccountsSummary\\(" "expected all-accounts summary recomputation"
require_pattern "${TRADE_TS}" "onSummaryChange\\(" "expected selected-account summary callback"
require_pattern "${TRADE_HTML}" "Total Cost Basis \\(All Accounts\\)" "expected all-accounts cost basis summary card"
require_pattern "${TRADE_HTML}" "Total Portfolio Value \\(All Accounts\\)" "expected all-accounts portfolio value summary card"
require_pattern "${TRADE_HTML}" "Total Net P&amp;L \\(All Accounts\\)" "expected all-accounts P&L summary card"
require_pattern "${TRADE_HTML}" "Account Cost Basis \\(" "expected selected-account cost basis summary card"
require_pattern "${TRADE_HTML}" "Account Portfolio Value \\(" "expected selected-account portfolio value summary card"
require_pattern "${TRADE_HTML}" "Account Net P&amp;L \\(" "expected selected-account P&L summary card"
require_pattern "${TRADE_HTML}" '\(summaryChange\)="onSummaryChange\([$]event\)"' "expected position blotter summaryChange binding"
require_pattern "${POSITION_BLOTTER_TS}" "@Output\\(\\) summaryChange" "expected position blotter to emit portfolio summaries"
require_pattern "${POSITION_BLOTTER_TS}" "this\\.summaryChange\\.emit\\(" "expected position blotter summary emission"

if [[ "${EXPECT_ORDER_UI}" -eq 1 ]]; then
  echo "[check] order-management trade/admin UI inheritance contract"
  require_pattern "${TRADE_TS}" "activeBlotter: 'trades' \\| 'orders'" "expected trade/order blotter mode state"
  require_pattern "${TRADE_TS}" "setBlotterMode\\(" "expected trade/order blotter mode switch handler"
  require_pattern "${TRADE_TS}" "this\\.activeBlotter = 'orders'" "expected order creation or intent to reveal orders view"
  require_pattern "${TRADE_HTML}" "Create Order Ticket|Create Order" "expected order ticket launcher"
  require_pattern "${TRADE_HTML}" "Trades / Positions" "expected trades/positions tab label"
  require_pattern "${TRADE_HTML}" "Orders" "expected orders tab label"
  require_pattern "${TRADE_HTML}" "\\*ngIf=\"activeBlotter === 'trades'\"" "expected trades/positions view gating"
  require_pattern "${TRADE_HTML}" "\\*ngIf=\"activeBlotter === 'orders'\"" "expected orders view gating"
  require_pattern "${TRADE_HTML}" "app-order-blotter" "expected account-scoped order blotter"
  require_pattern "${HEADER_HTML}" "routerLink=\"/admin\"[^>]*>Admin<" "expected Admin functional tab"
  require_pattern "${ROUTING_TS}" "path: 'admin'" "expected Admin route registration"
  require_pattern "${ROUTING_TS}" "OrderAdminComponent" "expected Admin route to use order manager component"
  require_pattern "${ADMIN_TS}" "selector: 'app-order-admin'" "expected order admin component"
  require_pattern "${ADMIN_TS}" "forceFillOrder\\(" "expected order admin force-fill workflow"
  require_pattern "${ADMIN_TS}" "cancelOrder\\(" "expected order admin cancel workflow"
  require_pattern "${ADMIN_HTML}" "Order Matcher Admin" "expected order admin page heading"
fi

echo "[done] web-front-end-angular pricing/order UX contract checks passed"
