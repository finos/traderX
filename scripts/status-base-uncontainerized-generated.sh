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
TARGET="${GENERATED_ROOT}/code/target-generated"
RUN_DIR="${TARGET}/.run/base-uncontainerized"
SPEC="${REPO_ROOT}/catalog/base-uncontainerized-processes.csv"
source "${REPO_ROOT}/scripts/lib/generated-state-detection.sh"

current_generated_state="$(traderx_read_generated_state_id "${GENERATED_ROOT}" || true)"
if [[ -n "${current_generated_state}" ]]; then
  echo "[info] generated output state: ${current_generated_state}"
else
  echo "[warn] generated output state is unknown (missing ci/state-metadata.json)"
fi

printf "%-24s %-10s %-8s %-12s\n" "process" "pid" "running" "port-open"
printf "%-24s %-10s %-8s %-12s\n" "------------------------" "----------" "--------" "------------"

while IFS=, read -r order process workdir start_cmd port health_hint build_cmd; do
  if [[ "${order}" == "order" ]]; then
    continue
  fi
  pidfile="${RUN_DIR}/pids/${process}.pid"
  pid="-"
  running="no"
  port_open="no"

  if [[ -f "${pidfile}" ]]; then
    pid="$(cat "${pidfile}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      running="yes"
    fi
  fi

  if nc -z localhost "${port}" >/dev/null 2>&1; then
    port_open="yes"
  fi

  printf "%-24s %-10s %-8s %-12s\n" "${process}" "${pid}" "${running}" "${port_open}"
done < "${SPEC}"
