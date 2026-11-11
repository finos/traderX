#!/usr/bin/env bash

traderx_state_order_number() {
  local state_id="$1"
  if [[ "${state_id}" =~ ^([0-9]{3})- ]]; then
    printf '%d' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

traderx_read_generated_state_id() {
  local generated_root="$1"
  local metadata_path="${generated_root}/code/target-generated/ci/state-metadata.json"
  local state_id=""

  if [[ ! -f "${metadata_path}" ]]; then
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    state_id="$(jq -r '.stateId // empty' "${metadata_path}" 2>/dev/null || true)"
  fi

  if [[ -z "${state_id}" ]]; then
    state_id="$(grep -Eo '"stateId"[[:space:]]*:[[:space:]]*"[^"]+"' "${metadata_path}" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  fi

  [[ -n "${state_id}" ]] || return 1
  printf '%s' "${state_id}"
}

traderx_report_generated_state() {
  local expected_state="$1"
  local generated_root="$2"
  local metadata_path="${generated_root}/code/target-generated/ci/state-metadata.json"
  local current_state=""

  current_state="$(traderx_read_generated_state_id "${generated_root}" || true)"

  if [[ -z "${current_state}" ]]; then
    echo "[warn] unable to detect current generated state (missing/invalid: ${metadata_path})"
    echo "[hint] run: bash pipeline/generate-state.sh ${expected_state}"
    return 2
  fi

  echo "[info] generated output state: ${current_state}"

  if [[ "${current_state}" == "${expected_state}" ]]; then
    echo "[info] generated output matches expected state: ${expected_state}"
    return 0
  fi

  echo "[warn] expected generated state ${expected_state}, found ${current_state}"

  local expected_num=""
  local current_num=""
  expected_num="$(traderx_state_order_number "${expected_state}" || true)"
  current_num="$(traderx_state_order_number "${current_state}" || true)"

  if [[ -n "${expected_num}" && -n "${current_num}" ]]; then
    if (( current_num < expected_num )); then
      echo "[hint] this is a forward transition (older -> newer). Regeneration is usually safe."
    elif (( current_num > expected_num )); then
      echo "[hint] this is a backward transition (newer -> older). Clean rebuild/regeneration is recommended."
    fi
  fi

  echo "[hint] regenerate now: bash pipeline/generate-state.sh ${expected_state}"
  echo "[hint] set TRADERX_REGENERATE_ON_STATE_MISMATCH=1 to auto-regenerate before startup"
  return 3
}

traderx_ensure_generated_state() {
  local expected_state="$1"
  local repo_root="$2"
  local generated_root="$3"
  local status=0

  traderx_report_generated_state "${expected_state}" "${generated_root}" || status=$?

  if (( status != 0 )) && [[ "${TRADERX_REGENERATE_ON_STATE_MISMATCH:-0}" == "1" ]] && [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
    echo "[action] regenerating expected state ${expected_state}"
    bash "${repo_root}/pipeline/generate-state.sh" "${expected_state}"
    status=0
    traderx_report_generated_state "${expected_state}" "${generated_root}" || status=$?
  fi

  if (( status != 0 )) && [[ "${TRADERX_STATE_MISMATCH_STRICT:-0}" == "1" ]]; then
    echo "[error] generated state mismatch remains (TRADERX_STATE_MISMATCH_STRICT=1)"
    return 1
  fi

  return 0
}
