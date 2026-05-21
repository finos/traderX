#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${1:-${GENERATED_ROOT}/code/target-generated}"
STATE_METADATA="${TARGET_ROOT}/ci/state-metadata.json"
STATE_CATALOG="${ROOT}/catalog/state-catalog.json"

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

state_num=""
state_feature_pack=""
state_map_file=""
parent_state_id=""
parent_feature_pack=""
parent_map_file=""
if [[ -n "${state_id}" ]] && [[ -f "${STATE_CATALOG}" ]] && command -v jq >/dev/null 2>&1; then
  state_num="${state_id%%-*}"
  state_feature_pack="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | .featurePack // ""' "${STATE_CATALOG}")"
  parent_state_id="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | ((.previous // [])[0] // "")' "${STATE_CATALOG}")"
  if [[ -n "${state_feature_pack}" ]]; then
    state_map_file="${ROOT}/${state_feature_pack}/system/messaging-subject-map.md"
  fi
  if [[ -n "${parent_state_id}" ]]; then
    parent_feature_pack="$(jq -r --arg id "${parent_state_id}" '.states[] | select(.id == $id) | .featurePack // ""' "${STATE_CATALOG}")"
    if [[ -n "${parent_feature_pack}" ]]; then
      parent_map_file="${ROOT}/${parent_feature_pack}/system/messaging-subject-map.md"
    fi
  fi
fi

if [[ -n "${state_num}" ]] && [[ "${state_num}" =~ ^[0-9]+$ ]] && (( 10#${state_num} >= 6 )); then
  if [[ -z "${state_map_file}" || ! -f "${state_map_file}" ]]; then
    echo "[fail] messaging subject-map contract violation: missing state map for ${state_id}"
    echo "[hint] expected: ${state_map_file:-<unresolved-from-catalog>}"
    exit 1
  fi

  if ! rg -q '^## Subject Families' "${state_map_file}"; then
    echo "[fail] messaging subject-map contract violation: ${state_map_file} missing '## Subject Families'"
    exit 1
  fi

  for required_field in 'delivery:' 'wildcard:' 'scope:' 'payload:'; do
    if ! rg -q "${required_field}" "${state_map_file}"; then
      echo "[fail] messaging subject-map contract violation: ${state_map_file} missing required field '${required_field}'"
      echo "[hint] follow docs/spec-kit/messaging-subject-map-standard.md"
      exit 1
    fi
  done

  echo "[ok] messaging subject-map presence/shape validated for ${state_id}"
fi

if [[ -d "${TARGET_ROOT}/order-matcher" ]]; then
  if [[ -z "${state_map_file}" || ! -f "${state_map_file}" ]]; then
    echo "[fail] order-matcher contract violation: state messaging subject map missing"
    echo "[hint] expected: ${state_map_file:-<unresolved-from-catalog>}"
    exit 1
  fi

  if ! rg -Fq '/accounts/<accountId>/orders' "${state_map_file}"; then
    echo "[fail] order-matcher contract violation: state messaging map missing '/accounts/<accountId>/orders'"
    exit 1
  fi
  if ! rg -Fq '/orders' "${state_map_file}"; then
    echo "[fail] order-matcher contract violation: state messaging map missing '/orders'"
    exit 1
  fi

  if [[ -n "${parent_map_file}" && -f "${parent_map_file}" ]] && cmp -s "${state_map_file}" "${parent_map_file}"; then
    if ! rg -Fq '/accounts/<accountId>/orders' "${parent_map_file}" || ! rg -Fq '/orders' "${parent_map_file}"; then
      echo "[fail] order-matcher contract violation: messaging subject map is unmodified from parent without order subjects"
      echo "[hint] update ${state_map_file} with order subject families"
      exit 1
    fi
  fi

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
