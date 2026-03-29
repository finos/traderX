#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/generated/code/target-generated"
RUN_DIR="${TARGET}/.run/base-uncontainerized"
SPEC="${REPO_ROOT}/catalog/base-uncontainerized-processes.csv"

printf "%-24s %-10s %-8s %-12s\n" "process" "pid" "running" "port-open"
printf "%-24s %-10s %-8s %-12s\n" "------------------------" "----------" "--------" "------------"

while IFS=, read -r order process workdir start_cmd port health_hint; do
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
