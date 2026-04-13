#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${1:-${GENERATED_ROOT}/code/target-generated}"
STATE_METADATA="${TARGET_ROOT}/ci/state-metadata.json"

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

state_id=""
if [[ -f "${STATE_METADATA}" ]] && command -v jq >/dev/null 2>&1; then
  state_id="$(jq -r '.stateId // ""' "${STATE_METADATA}")"
fi
if [[ -n "${state_id}" ]]; then
  echo "[info] validating generated-state contracts for ${state_id}"
else
  echo "[info] validating generated-state contracts for ${TARGET_ROOT}"
fi

if [[ -d "${TARGET_ROOT}/order-matcher" ]]; then
  schema_file="${TARGET_ROOT}/database/initialSchema.sql"
  if [[ ! -f "${schema_file}" ]]; then
    echo "[fail] order-matcher contract violation: missing database schema file ${schema_file}"
    exit 1
  fi

  if ! rg -qi 'create[[:space:]]+table[[:space:]]+orderbook' "${schema_file}"; then
    echo "[fail] order-matcher contract violation: OrderBook table missing from ${schema_file}"
    echo "[hint] generated states that include order-matcher must seed OrderBook deterministically"
    exit 1
  fi

  if ! rg -q 'OrderId' "${schema_file}"; then
    echo "[fail] order-matcher contract violation: OrderBook.OrderId column missing from ${schema_file}"
    exit 1
  fi

  if ! rg -q 'Status' "${schema_file}"; then
    echo "[fail] order-matcher contract violation: OrderBook.Status column missing from ${schema_file}"
    exit 1
  fi

  echo "[ok] order-matcher schema contract validated (OrderBook present)"
else
  echo "[info] order-matcher not present; skipping order schema contract check"
fi

echo "[ok] generated-state contracts validated for ${TARGET_ROOT}"
