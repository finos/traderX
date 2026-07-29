#!/usr/bin/env bash
set -euo pipefail

SAIL_PIN_FILE="${SAIL_PIN_FILE:-/workspace/bootstrap/sail-pin.env}"
if [[ -f "${SAIL_PIN_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${SAIL_PIN_FILE}"
fi

SAIL_REPO_URL="${SAIL_REPO_URL:-${SAIL_PIN_REPO_URL:-https://github.com/finos/FDC3-Sail.git}}"
SAIL_REPO_REF="${SAIL_REPO_REF:-${SAIL_PIN_REPO_REF:-${SAIL_PINNED_REF:-${SAIL_PIN_TRACKING_REF:-main}}}}"
SAIL_REPO_REF="${SAIL_REPO_REF#origin/}"
SAIL_REPO_COMMIT="${SAIL_REPO_COMMIT:-${SAIL_PIN_REPO_COMMIT:-${SAIL_PINNED_REF:-}}}"
SAIL_REPO_DIR="${SAIL_REPO_DIR:-/workspace/runtime-cache/FDC3-Sail}"
SAIL_TRADERX_URL="${SAIL_TRADERX_URL:-http://localhost:8080}"
SAIL_APPD_BASE="${SAIL_REPO_DIR}/packages/fdc3-example-apps/directory/generated/fdc3-example-apps.json"
SAIL_TRADERX_APPD="/workspace/appd/traderx.appd.v2.json"

mkdir -p "$(dirname "${SAIL_REPO_DIR}")"

if [[ ! -d "${SAIL_REPO_DIR}/.git" ]]; then
  if [[ -n "${SAIL_REPO_COMMIT}" ]]; then
    echo "[info] cloning Sail repository (pinned commit ${SAIL_REPO_COMMIT})"
    git clone "${SAIL_REPO_URL}" "${SAIL_REPO_DIR}"
    git -C "${SAIL_REPO_DIR}" checkout --force "${SAIL_REPO_COMMIT}"
  else
    echo "[info] cloning Sail repository (${SAIL_REPO_REF})"
    git clone --depth 1 --branch "${SAIL_REPO_REF}" "${SAIL_REPO_URL}" "${SAIL_REPO_DIR}"
  fi
else
  if [[ -n "${SAIL_REPO_COMMIT}" ]]; then
    echo "[info] updating Sail repository (pinned commit ${SAIL_REPO_COMMIT})"
    git -C "${SAIL_REPO_DIR}" fetch --prune origin
    git -C "${SAIL_REPO_DIR}" checkout --force "${SAIL_REPO_COMMIT}"
  else
    echo "[info] updating Sail repository (${SAIL_REPO_REF})"
    git -C "${SAIL_REPO_DIR}" fetch --depth 1 origin "${SAIL_REPO_REF}"
    git -C "${SAIL_REPO_DIR}" checkout --force FETCH_HEAD
  fi
fi

cd "${SAIL_REPO_DIR}"

if [[ -x /workspace/bootstrap/apply-tradingview-overrides.sh ]]; then
  echo "[info] applying state-014 Sail overrides"
  /workspace/bootstrap/apply-tradingview-overrides.sh "${SAIL_REPO_DIR}"
fi

echo "[info] installing Sail dependencies"
rm -rf node_modules
npm install --no-audit --no-fund

echo "[info] building Sail workspace packages required by web desktop agent"
npm run build -w packages/da-impl --if-present
npm run build -w packages/common --if-present

echo "[start] launching Sail example apps (directory generator)"
npm run examples:dev &
EXAMPLES_PID=$!

wait_for_file() {
  local path="$1"
  local attempts="$2"
  local i
  for ((i=1; i<=attempts; i++)); do
    if [[ -s "${path}" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if ! wait_for_file "${SAIL_APPD_BASE}" 180; then
  echo "[error] timeout waiting for generated Sail app directory: ${SAIL_APPD_BASE}"
  kill "${EXAMPLES_PID}" >/dev/null 2>&1 || true
  exit 1
fi

echo "[info] merging TraderX app record into Sail generated directory"
/workspace/bootstrap/merge-traderx-appd.sh "${SAIL_APPD_BASE}" "${SAIL_TRADERX_APPD}" "${SAIL_TRADERX_URL}"

reconcile_traderx_overlay() {
  while true; do
    if [[ -s "${SAIL_APPD_BASE}" ]]; then
      /workspace/bootstrap/merge-traderx-appd.sh "${SAIL_APPD_BASE}" "${SAIL_TRADERX_APPD}" "${SAIL_TRADERX_URL}" || true
    fi
    sleep 5
  done
}

reconcile_traderx_overlay &
RECONCILE_PID=$!

echo "[start] launching Sail web desktop agent"
npm run web:dev &
WEB_PID=$!

cleanup() {
  kill "${RECONCILE_PID}" >/dev/null 2>&1 || true
  kill "${WEB_PID}" >/dev/null 2>&1 || true
  kill "${EXAMPLES_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

set +e
wait -n "${EXAMPLES_PID}" "${WEB_PID}"
status="$?"
set -e

if [[ "${status}" -ne 0 ]]; then
  echo "[error] Sail process exited unexpectedly (status=${status})"
fi
exit "${status}"
