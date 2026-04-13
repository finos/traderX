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
  schema_files=()
  postgres_schema_file="${TARGET_ROOT}/postgres-database-replacement/postgres-init/initialSchema.sql"
  h2_schema_file="${TARGET_ROOT}/database/initialSchema.sql"
  if [[ -f "${postgres_schema_file}" ]]; then
    schema_files+=("${postgres_schema_file}")
  fi
  if [[ -f "${h2_schema_file}" ]]; then
    schema_files+=("${h2_schema_file}")
  fi

  if [[ "${#schema_files[@]}" -eq 0 ]]; then
    echo "[fail] order-matcher contract violation: no schema files found for order-matcher validation"
    echo "[hint] expected one of:"
    echo "       - ${postgres_schema_file}"
    echo "       - ${h2_schema_file}"
    exit 1
  fi

  for schema_file in "${schema_files[@]}"; do
    if ! rg -qi 'create[[:space:]]+table[[:space:]]+orderbook' "${schema_file}"; then
      echo "[fail] order-matcher contract violation: OrderBook table missing from ${schema_file}"
      echo "[hint] generated states that include order-matcher must seed OrderBook deterministically"
      exit 1
    fi

    if ! rg -qi '\borderid\b' "${schema_file}"; then
      echo "[fail] order-matcher contract violation: OrderBook.orderId column missing from ${schema_file}"
      exit 1
    fi

    if ! rg -qi '\bstatus[[:space:]]+varchar' "${schema_file}"; then
      echo "[fail] order-matcher contract violation: OrderBook.status column missing from ${schema_file}"
      exit 1
    fi
  done

  echo "[ok] order-matcher schema contract validated (OrderBook present in ${#schema_files[@]} schema file(s))"
else
  echo "[info] order-matcher not present; skipping order schema contract check"
fi

echo "[ok] generated-state contracts validated for ${TARGET_ROOT}"
