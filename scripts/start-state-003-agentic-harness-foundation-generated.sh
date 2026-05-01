#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"
SOURCE_REPO_ROOT="${TRADERX_SOURCE_REPO_ROOT:-${REPO_ROOT}}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    TRADERX_LOCAL_RUNTIME_SCRIPT=1 \
    TRADERX_GENERATED_ROOT="${GENERATED_ROOT}" \
    TRADERX_SOURCE_REPO_ROOT="${SOURCE_REPO_ROOT}" \
      exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi
TARGET="${GENERATED_ROOT}/code/target-generated"
EXPECTED_STATE="003-agentic-harness-foundation"
RUN_DIR="${TARGET}/.run/state-003-agentic-harness-foundation"
EDGE_COMPONENT_DIR="${GENERATED_ROOT}/code/components/edge-proxy-specfirst"
EDGE_TARGET_DIR="${TARGET}/edge-proxy"
EDGE_PROXY_PORT="${EDGE_PROXY_PORT:-18080}"
DRY_RUN=0
BUILD_ONLY=0

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --build-only)
      BUILD_ONLY=1
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run --build-only"
      exit 1
      ;;
  esac
  shift
done

[[ -d "${EDGE_COMPONENT_DIR}" ]] || {
  echo "[error] missing generated edge-proxy component: ${EDGE_COMPONENT_DIR}"
  echo "[hint] run: bash pipeline/generate-state.sh 003-agentic-harness-foundation"
  exit 1
}

if (( DRY_RUN == 1 )) && (( BUILD_ONLY == 1 )); then
  TRADERX_EXPECTED_STATE_ID="${EXPECTED_STATE}" \
  TRADERX_GENERATED_ROOT="${GENERATED_ROOT}" \
  TRADERX_SOURCE_REPO_ROOT="${SOURCE_REPO_ROOT}" \
    "${REPO_ROOT}/scripts/start-base-uncontainerized-generated.sh" --dry-run --build-only
elif (( DRY_RUN == 1 )); then
  TRADERX_EXPECTED_STATE_ID="${EXPECTED_STATE}" \
  TRADERX_GENERATED_ROOT="${GENERATED_ROOT}" \
  TRADERX_SOURCE_REPO_ROOT="${SOURCE_REPO_ROOT}" \
    "${REPO_ROOT}/scripts/start-base-uncontainerized-generated.sh" --dry-run
elif (( BUILD_ONLY == 1 )); then
  TRADERX_EXPECTED_STATE_ID="${EXPECTED_STATE}" \
  TRADERX_GENERATED_ROOT="${GENERATED_ROOT}" \
  TRADERX_SOURCE_REPO_ROOT="${SOURCE_REPO_ROOT}" \
    "${REPO_ROOT}/scripts/start-base-uncontainerized-generated.sh" --build-only
else
  TRADERX_EXPECTED_STATE_ID="${EXPECTED_STATE}" \
  TRADERX_GENERATED_ROOT="${GENERATED_ROOT}" \
  TRADERX_SOURCE_REPO_ROOT="${SOURCE_REPO_ROOT}" \
    "${REPO_ROOT}/scripts/start-base-uncontainerized-generated.sh"
fi

mkdir -p "${RUN_DIR}/logs" "${RUN_DIR}/pids"
if [[ ! -d "${EDGE_TARGET_DIR}" ]]; then
  cp -R "${EDGE_COMPONENT_DIR}" "${EDGE_TARGET_DIR}"
fi

if (( BUILD_ONLY == 1 )); then
  if [[ -d "${EDGE_TARGET_DIR}/node_modules" ]]; then
    echo "[build-skip] edge-proxy: already built"
  elif (( DRY_RUN == 1 )); then
    echo "[dry-run] [build] edge-proxy: cd ${EDGE_TARGET_DIR} && npm install"
  else
    echo "[build] edge-proxy: npm install"
    (cd "${EDGE_TARGET_DIR}" && npm install)
  fi

  if (( DRY_RUN == 1 )); then
    echo "[done] dry run complete for state 003"
  else
    echo "[done] build phase complete for state 003"
    echo "[hint] run without --build-only to start services"
  fi
  exit 0
fi

if [[ ! -d "${EDGE_TARGET_DIR}/node_modules" ]]; then
  echo "[error] edge-proxy build artifacts missing (node_modules)."
  echo "[hint] run ./scripts/start-state-003-agentic-harness-foundation-generated.sh --build-only"
  exit 1
fi

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
  echo "[hint] run ./scripts/stop-state-003-agentic-harness-foundation-generated.sh and retry."
  exit 1
fi

if (( DRY_RUN == 1 )); then
  echo "[dry-run] edge-proxy: cd ${EDGE_TARGET_DIR} && npm run start"
  echo "[done] dry run complete for state 003"
  exit 0
fi

echo "[start] edge-proxy"
nohup /bin/zsh -lc "cd '${EDGE_TARGET_DIR}' && npm run start" >"${logfile}" 2>&1 &
echo "$!" > "${pidfile}"

attempts=60
for ((i=1; i<=attempts; i++)); do
  if nc -z localhost "${EDGE_PROXY_PORT}" >/dev/null 2>&1; then
    echo "[ready] edge-proxy on :${EDGE_PROXY_PORT}"
    echo "[ui] http://localhost:${EDGE_PROXY_PORT}"
    echo "[api-explorer] http://localhost:${EDGE_PROXY_PORT}/api/docs"
    exit 0
  fi
  sleep 1
done

echo "[error] timeout waiting for edge-proxy on :${EDGE_PROXY_PORT}"
echo "[hint] check logs: ${logfile}"
exit 1
