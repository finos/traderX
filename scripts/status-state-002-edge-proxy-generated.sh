#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/generated/code/target-generated"
RUN_DIR="${TARGET}/.run/state-002-edge-proxy"
EDGE_PROXY_PORT="${EDGE_PROXY_PORT:-18080}"

"${REPO_ROOT}/scripts/status-base-uncontainerized-generated.sh"

pidfile="${RUN_DIR}/pids/edge-proxy.pid"
pid="-"
running="no"
port_open="no"

if [[ -f "${pidfile}" ]]; then
  pid="$(cat "${pidfile}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    running="yes"
  fi
fi

if nc -z localhost "${EDGE_PROXY_PORT}" >/dev/null 2>&1; then
  port_open="yes"
fi

printf "%-24s %-10s %-8s %-12s\n" "edge-proxy" "${pid}" "${running}" "${port_open}"
