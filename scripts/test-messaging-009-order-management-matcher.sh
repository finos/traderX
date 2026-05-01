#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
TRADE_SERVICE_URL="${2:-http://localhost:18092}"
ACCOUNT_ID="${3:-22214}"
ADMIN_ACCOUNT_ID="${4:-44044}"
SUBJECT_MAP_FILE="${5:-specs/009-order-management-matcher/system/messaging-subject-map.md}"
TIMEOUT_MS="${TIMEOUT_MS:-35000}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(git -C "${REPO_ROOT}" rev-parse --show-toplevel 2>/dev/null || printf '%s' "${REPO_ROOT}")"

resolve_subject_map_path() {
  local candidate="$1"
  if [[ -f "${candidate}" ]]; then
    echo "${candidate}"
    return
  fi
  if [[ -f "${REPO_ROOT}/${candidate}" ]]; then
    echo "${REPO_ROOT}/${candidate}"
    return
  fi
  if [[ -f "${WORKSPACE_ROOT}/${candidate}" ]]; then
    echo "${WORKSPACE_ROOT}/${candidate}"
    return
  fi
  echo "${WORKSPACE_ROOT}/${candidate}"
}

warn_uncovered_subjects() {
  local map_file="$1"
  shift
  local covered=("$@")
  local uncovered=0

  if [[ ! -f "${map_file}" ]]; then
    echo "[warn] subject map not found for coverage warnings: ${map_file}"
    return 0
  fi

  while IFS= read -r subject; do
    local is_covered=0
    for pattern in "${covered[@]}"; do
      if [[ "${subject}" == "${pattern}" ]]; then
        is_covered=1
        break
      fi
    done
    if [[ "${is_covered}" -eq 0 ]]; then
      echo "[warn] SUBJECT_WITHOUT_TRIGGER_COVERAGE: ${subject}"
      uncovered=$((uncovered + 1))
    fi
  done < <(sed -n 's/^- `\([^`]*\)`.*/\1/p' "${map_file}")

  if [[ "${uncovered}" -eq 0 ]]; then
    echo "[info] subject map coverage warnings: none"
  fi
}

echo "[check] message bus websocket reachability pre-check"
INGRESS_URL="${INGRESS_URL}" TIMEOUT_MS="${TIMEOUT_MS}" node <<'NODE'
const ingressUrl = process.env.INGRESS_URL || 'http://localhost:8080';
const timeoutMs = Number(process.env.TIMEOUT_MS || '35000');
const wsUrl = ingressUrl.replace(/^http/i, 'ws') + '/nats-ws';

if (typeof WebSocket !== 'function') {
  console.error('[error] MESSAGE_BUS_UNREACHABLE: global WebSocket unavailable in this Node runtime');
  process.exit(31);
}

const ws = new WebSocket(wsUrl);
const timer = setTimeout(() => {
  console.error(`[error] MESSAGE_BUS_UNREACHABLE: timeout connecting to ${wsUrl}`);
  process.exit(31);
}, Math.min(timeoutMs, 8000));

ws.onopen = () => {
  clearTimeout(timer);
  ws.close();
  console.log('[info] message bus websocket reachable');
  process.exit(0);
};

ws.onerror = () => {
  clearTimeout(timer);
  console.error(`[error] MESSAGE_BUS_UNREACHABLE: websocket error for ${wsUrl}`);
  process.exit(31);
};
NODE

warn_uncovered_subjects \
  "$(resolve_subject_map_path "${SUBJECT_MAP_FILE}")" \
  "/trades" \
  "/accounts/<accountId>/trades" \
  "/accounts/<accountId>/positions" \
  "pricing.<TICKER>" \
  "/accounts/<accountId>/orders" \
  "/orders"

echo "[check] messaging flow assertions for state 009 subject map"
if ! TRADERX_LOCAL_RUNTIME_SCRIPT=1 TIMEOUT_MS="${TIMEOUT_MS}" \
  "${REPO_ROOT}/scripts/test-messaging-008-pricing-awareness-market-data.sh" \
  "${INGRESS_URL}" "${TRADE_SERVICE_URL}" "${ACCOUNT_ID}"; then
  echo "[error] NO_MESSAGE_RECEIVED_ON_SUBJECT: baseline trade/position/pricing messaging assertions failed"
  exit 1
fi

if ! TRADERX_LOCAL_RUNTIME_SCRIPT=1 TIMEOUT_MS="${TIMEOUT_MS}" \
  "${REPO_ROOT}/scripts/test-order-create-pubsub-smoke.sh" \
  "${INGRESS_URL}" "${ACCOUNT_ID}"; then
  echo "[error] NO_MESSAGE_RECEIVED_ON_SUBJECT: missing NEW order publish events on /accounts/<accountId>/orders or /orders"
  exit 1
fi

if ! TRADERX_LOCAL_RUNTIME_SCRIPT=1 TIMEOUT_MS="${TIMEOUT_MS}" \
  "${REPO_ROOT}/scripts/test-realtime-order-stream-overlay.sh" \
  "${INGRESS_URL}" "${ACCOUNT_ID}" "${ADMIN_ACCOUNT_ID}"; then
  echo "[error] NO_MESSAGE_RECEIVED_ON_SUBJECT: missing FILLED/PARTIALLY_FILLED order stream events or dependent trade/position events"
  exit 1
fi

echo "[done] state 009 messaging smoke tests passed"
