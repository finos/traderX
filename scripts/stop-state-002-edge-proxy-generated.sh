#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/generated/code/target-generated"
RUN_DIR="${TARGET}/.run/state-002-edge-proxy"
EDGE_PROXY_PORT="${EDGE_PROXY_PORT:-18080}"

pidfile="${RUN_DIR}/pids/edge-proxy.pid"
if [[ -f "${pidfile}" ]]; then
  pid="$(cat "${pidfile}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    echo "[stop] edge-proxy (pid ${pid})"
    kill "${pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${pidfile}"
fi

if command -v lsof >/dev/null 2>&1; then
  pids="$(lsof -nP -tiTCP:"${EDGE_PROXY_PORT}" -sTCP:LISTEN 2>/dev/null || true)"
  for pid in ${pids}; do
    if kill -0 "${pid}" >/dev/null 2>&1; then
      echo "[stop-port] edge-proxy listener on :${EDGE_PROXY_PORT} (pid ${pid})"
      kill "${pid}" >/dev/null 2>&1 || true
    fi
  done
fi

"${REPO_ROOT}/scripts/stop-base-uncontainerized-generated.sh"
