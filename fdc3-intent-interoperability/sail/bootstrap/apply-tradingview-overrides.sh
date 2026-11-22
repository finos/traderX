#!/usr/bin/env bash
set -euo pipefail

SAIL_REPO_DIR="${1:-/workspace/runtime-cache/FDC3-Sail}"
OVERRIDE_TRADINGVIEW_WIDGET="/workspace/bootstrap/overrides/tradingview/TradingViewWidget.tsx"
TARGET_TRADINGVIEW_WIDGET="${SAIL_REPO_DIR}/packages/fdc3-example-apps/front-end-apps/tradingview/src/TradingViewWidget.tsx"
OVERRIDE_TRADINGVIEW_MODES_DIR="/workspace/bootstrap/overrides/tradingview/modes"
TARGET_TRADINGVIEW_MODES_DIR="${SAIL_REPO_DIR}/packages/fdc3-example-apps/front-end-apps/tradingview/src/modes"
OVERRIDE_POLYGON_WIDGET="/workspace/bootstrap/overrides/polygon/PolygonWidget.tsx"
TARGET_POLYGON_WIDGET="${SAIL_REPO_DIR}/packages/fdc3-example-apps/server-apps/polygon/src/PolygonWidget.tsx"
OVERRIDE_WEB_DEFAULT_STATE="/workspace/bootstrap/overrides/web/default-client-state.json"
TARGET_WEB_DEFAULT_STATE="${SAIL_REPO_DIR}/packages/web/default-client-state.json"
OVERRIDE_WEB_CLIENT_INDEX="/workspace/bootstrap/overrides/web/src/client/index.tsx"
TARGET_WEB_CLIENT_INDEX="${SAIL_REPO_DIR}/packages/web/src/client/index.tsx"
OVERRIDE_TRADERX_INTENT_LAUNCHER_DIR="/workspace/bootstrap/overrides/traderx-intent-launcher"
TARGET_TRADERX_INTENT_LAUNCHER_DIR="${SAIL_REPO_DIR}/packages/fdc3-example-apps/front-end-apps/traderx-intent-launcher"

if [[ -f "${OVERRIDE_TRADINGVIEW_WIDGET}" ]]; then
  mkdir -p "$(dirname "${TARGET_TRADINGVIEW_WIDGET}")"
  cp "${OVERRIDE_TRADINGVIEW_WIDGET}" "${TARGET_TRADINGVIEW_WIDGET}"
  echo "[ok] applied TradingView widget override to ${TARGET_TRADINGVIEW_WIDGET}"
fi

if compgen -G "${OVERRIDE_TRADINGVIEW_MODES_DIR}/*.ts" > /dev/null; then
  mkdir -p "${TARGET_TRADINGVIEW_MODES_DIR}"
  cp "${OVERRIDE_TRADINGVIEW_MODES_DIR}/"*.ts "${TARGET_TRADINGVIEW_MODES_DIR}/"
  echo "[ok] applied TradingView mode overrides to ${TARGET_TRADINGVIEW_MODES_DIR}"
fi

if [[ -f "${OVERRIDE_POLYGON_WIDGET}" ]]; then
  mkdir -p "$(dirname "${TARGET_POLYGON_WIDGET}")"
  cp "${OVERRIDE_POLYGON_WIDGET}" "${TARGET_POLYGON_WIDGET}"
  echo "[ok] applied Polygon widget override to ${TARGET_POLYGON_WIDGET}"
fi

if [[ -f "${OVERRIDE_WEB_DEFAULT_STATE}" ]]; then
  mkdir -p "$(dirname "${TARGET_WEB_DEFAULT_STATE}")"
  cp "${OVERRIDE_WEB_DEFAULT_STATE}" "${TARGET_WEB_DEFAULT_STATE}"
  echo "[ok] applied Sail demo default client state to ${TARGET_WEB_DEFAULT_STATE}"
fi

if [[ -f "${OVERRIDE_WEB_CLIENT_INDEX}" ]]; then
  mkdir -p "$(dirname "${TARGET_WEB_CLIENT_INDEX}")"
  cp "${OVERRIDE_WEB_CLIENT_INDEX}" "${TARGET_WEB_CLIENT_INDEX}"
  echo "[ok] applied Sail web client bootstrap override to ${TARGET_WEB_CLIENT_INDEX}"
fi

if [[ -d "${OVERRIDE_TRADERX_INTENT_LAUNCHER_DIR}" ]]; then
  rm -rf "${TARGET_TRADERX_INTENT_LAUNCHER_DIR}"
  mkdir -p "${TARGET_TRADERX_INTENT_LAUNCHER_DIR}"
  cp -R "${OVERRIDE_TRADERX_INTENT_LAUNCHER_DIR}/." "${TARGET_TRADERX_INTENT_LAUNCHER_DIR}/"
  echo "[ok] applied TraderX intents launcher app override to ${TARGET_TRADERX_INTENT_LAUNCHER_DIR}"
fi
