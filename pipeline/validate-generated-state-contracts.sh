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

sail_state_dir="${TARGET_ROOT}/fdc3-intent-interoperability/sail"
if [[ -d "${sail_state_dir}" ]]; then
  pin_manifest="${sail_state_dir}/bootstrap/sail-pin.env"
  compose_file="${sail_state_dir}/docker-compose.yml"
  run_sail_script="${sail_state_dir}/bootstrap/run-sail.sh"

  for required in "${pin_manifest}" "${compose_file}" "${run_sail_script}"; do
    if [[ ! -f "${required}" ]]; then
      echo "[fail] Sail pin contract violation: missing ${required}"
      exit 1
    fi
  done

  # shellcheck disable=SC1090
  source "${pin_manifest}"
  if ! [[ "${SAIL_PINNED_REF:-}" =~ ^[0-9a-f]{40}$ ]]; then
    echo "[fail] Sail pin contract violation: SAIL_PINNED_REF missing/invalid in ${pin_manifest}"
    exit 1
  fi

  if ! rg -Fq "${SAIL_PINNED_REF}" "${compose_file}"; then
    echo "[fail] Sail pin contract violation: docker-compose does not default to pinned commit ${SAIL_PINNED_REF}"
    exit 1
  fi

  if ! rg -q 'sail-pin\.env' "${run_sail_script}"; then
    echo "[fail] Sail pin contract violation: run-sail bootstrap does not consume sail-pin.env"
    exit 1
  fi

  if ! rg -q 'SAIL_REPO_REF=.*SAIL_PINNED_REF' "${run_sail_script}"; then
    echo "[fail] Sail pin contract violation: run-sail bootstrap does not derive repo ref from SAIL_PINNED_REF"
    exit 1
  fi

  echo "[ok] Sail pin contract validated for state 014 artifacts"
else
  echo "[info] state 014 Sail assets not present; skipping Sail pin contract check"
fi

echo "[ok] generated-state contracts validated for ${TARGET_ROOT}"
