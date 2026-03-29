#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/generated/code/target-generated"
RUN_DIR="${TARGET}/.run/base-uncontainerized"
SPEC="${REPO_ROOT}/catalog/base-uncontainerized-processes.csv"

if [[ ! -d "${RUN_DIR}/pids" ]]; then
  echo "[info] no pid directory at ${RUN_DIR}/pids"
  mkdir -p "${RUN_DIR}/pids"
fi

kill_listener_on_port() {
  local process="$1"
  local port="$2"
  local pids

  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi

  pids="$(lsof -nP -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "${pids}" ]]; then
    return 0
  fi

  for pid in ${pids}; do
    if kill -0 "${pid}" >/dev/null 2>&1; then
      echo "[stop-port] ${process} listener on :${port} (pid ${pid})"
      kill "${pid}" >/dev/null 2>&1 || true
    fi
  done
}

while IFS=, read -r order process workdir start_cmd port health_hint; do
  if [[ "${order}" == "order" ]]; then
    continue
  fi
  pidfile="${RUN_DIR}/pids/${process}.pid"
  if [[ -f "${pidfile}" ]]; then
    pid="$(cat "${pidfile}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      echo "[stop] ${process} (pid ${pid})"
      kill "${pid}" >/dev/null 2>&1 || true
    else
      echo "[stale] ${process} pid file exists but process not running"
    fi
    rm -f "${pidfile}"
  fi
  kill_listener_on_port "${process}" "${port}"
done < <(tail -n +2 "${SPEC}" | sort -t, -k1,1nr)

echo "[done] stop sequence complete"
