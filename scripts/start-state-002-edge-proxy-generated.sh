#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${REPO_ROOT}/generated/code/target-generated"
RUN_DIR="${TARGET}/.run/state-002-edge-proxy"
EDGE_COMPONENT_DIR="${REPO_ROOT}/generated/code/components/edge-proxy-specfirst"
EDGE_TARGET_DIR="${TARGET}/edge-proxy"
EDGE_PROXY_PORT="${EDGE_PROXY_PORT:-18080}"
DRY_RUN=0

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run"
      exit 1
      ;;
  esac
  shift
done

[[ -d "${EDGE_COMPONENT_DIR}" ]] || {
  echo "[error] missing generated edge-proxy component: ${EDGE_COMPONENT_DIR}"
  echo "[hint] run: bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized"
  exit 1
}

if (( DRY_RUN == 1 )); then
  "${REPO_ROOT}/scripts/start-base-uncontainerized-generated.sh" --dry-run
else
  "${REPO_ROOT}/scripts/start-base-uncontainerized-generated.sh"
fi

mkdir -p "${RUN_DIR}/logs" "${RUN_DIR}/pids"
rm -rf "${EDGE_TARGET_DIR}"
cp -R "${EDGE_COMPONENT_DIR}" "${EDGE_TARGET_DIR}"

pidfile="${RUN_DIR}/pids/edge-proxy.pid"
logfile="${RUN_DIR}/logs/edge-proxy.log"

if [[ -f "${pidfile}" ]]; then
  oldpid="$(cat "${pidfile}")"
  if kill -0 "${oldpid}" >/dev/null 2>&1; then
    echo "[skip] edge-proxy already running (pid ${oldpid})"
    exit 0
  fi
fi

if nc -z localhost "${EDGE_PROXY_PORT}" >/dev/null 2>&1; then
  echo "[error] port :${EDGE_PROXY_PORT} already in use before starting edge-proxy"
  echo "[hint] run ./scripts/stop-state-002-edge-proxy-generated.sh and retry."
  exit 1
fi

if (( DRY_RUN == 1 )); then
  echo "[dry-run] edge-proxy: cd ${EDGE_TARGET_DIR} && [ -d node_modules ] || npm install; npm run start"
  echo "[done] dry run complete for state 002"
  exit 0
fi

echo "[start] edge-proxy"
nohup /bin/zsh -lc "cd '${EDGE_TARGET_DIR}' && [ -d node_modules ] || npm install; npm run start" >"${logfile}" 2>&1 &
echo "$!" > "${pidfile}"

attempts=60
for ((i=1; i<=attempts; i++)); do
  if nc -z localhost "${EDGE_PROXY_PORT}" >/dev/null 2>&1; then
    echo "[ready] edge-proxy on :${EDGE_PROXY_PORT}"
    echo "[ui] http://localhost:${EDGE_PROXY_PORT}"
    exit 0
  fi
  sleep 1
done

echo "[error] timeout waiting for edge-proxy on :${EDGE_PROXY_PORT}"
echo "[hint] check logs: ${logfile}"
exit 1
