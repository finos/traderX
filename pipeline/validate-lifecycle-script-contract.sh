#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT}/scripts"
CATALOG="${ROOT}/catalog/base-uncontainerized-processes.csv"

fail() {
  echo "[fail] $*"
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "missing file: ${path}"
}

require_pattern_in_file() {
  local pattern="$1"
  local path="$2"
  if ! rg -q -- "${pattern}" "${path}"; then
    fail "missing required pattern '${pattern}' in ${path}"
  fi
}

require_file "${SCRIPTS_DIR}/start-base-uncontainerized-generated.sh"
require_file "${SCRIPTS_DIR}/stop-base-uncontainerized-generated.sh"
require_file "${SCRIPTS_DIR}/test-order-create-pubsub-smoke.sh"
require_file "${CATALOG}"

# Baseline contract: catalog must expose build_cmd and every process row must define it.
header="$(head -n 1 "${CATALOG}")"
[[ "${header}" == *",build_cmd" ]] || fail "${CATALOG} must include build_cmd column"

awk -F, 'NR > 1 { if ($7 == "") { printf("[fail] missing build_cmd for process %s on row %d\n", $2, NR); exit 1 } }' "${CATALOG}"

# Uncontainerized lifecycle scripts must expose explicit build-only mode.
require_pattern_in_file '--build-only' "${SCRIPTS_DIR}/start-base-uncontainerized-generated.sh"

for state_num in 002 003; do
  start_script="$(find "${SCRIPTS_DIR}" -maxdepth 1 -type f -name "start-state-${state_num}-*-generated.sh" | sort | head -n 1 || true)"
  stop_script="$(find "${SCRIPTS_DIR}" -maxdepth 1 -type f -name "stop-state-${state_num}-*-generated.sh" | sort | head -n 1 || true)"
  smoke_script="$(find "${SCRIPTS_DIR}" -maxdepth 1 -type f -name "test-state-${state_num}-*.sh" | sort | head -n 1 || true)"

  [[ -n "${start_script}" ]] || fail "missing start script for state ${state_num}"
  [[ -n "${stop_script}" ]] || fail "missing stop script for state ${state_num}"
  [[ -n "${smoke_script}" ]] || fail "missing readiness script for state ${state_num}"

  require_pattern_in_file '--build-only' "${start_script}"
done

# Every other generated state must have start/stop/readiness scripts and build/start separation flag.
for state_num in 004 005 006 007 008 009 010 011 012 013 014; do
  start_script="$(find "${SCRIPTS_DIR}" -maxdepth 1 -type f -name "start-state-${state_num}-*-generated.sh" | sort | head -n 1 || true)"
  stop_script="$(find "${SCRIPTS_DIR}" -maxdepth 1 -type f -name "stop-state-${state_num}-*-generated.sh" | sort | head -n 1 || true)"
  smoke_script="$(find "${SCRIPTS_DIR}" -maxdepth 1 -type f -name "test-state-${state_num}-*.sh" | sort | head -n 1 || true)"

  [[ -n "${start_script}" ]] || fail "missing start script for state ${state_num}"
  [[ -n "${stop_script}" ]] || fail "missing stop script for state ${state_num}"
  [[ -n "${smoke_script}" ]] || fail "missing readiness script for state ${state_num}"

  if ! rg -q -- '--build-only|--skip-build' "${start_script}"; then
    fail "start script must support build/start separation flag (--build-only or --skip-build): ${start_script}"
  fi
done

echo "[ok] lifecycle script contract validation passed"
