#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_ROOT="${ROOT}/upstream/traderX"
STATE_ID="${1:-003-containerized-compose-runtime}"
TARGET_ROOT="${ROOT}/generated/code/target-generated"
OVERLAY_GENERATED_ROOT="${ROOT}/generated"

if [[ ! -d "${UPSTREAM_ROOT}" ]]; then
  echo "[fail] upstream submodule not found at ${UPSTREAM_ROOT}"
  echo "[hint] run: git submodule update --init --recursive"
  exit 1
fi

echo "[info] generating upstream state ${STATE_ID}"
TRADERX_GENERATED_ROOT="${OVERLAY_GENERATED_ROOT}" bash "${UPSTREAM_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"

echo "[info] applying corporate transforms"
bash "${ROOT}/corporate/transforms/managed-postgres-endpoint-overlay.sh" "${TARGET_ROOT}" "${STATE_ID}"
bash "${ROOT}/corporate/transforms/docs-internal-banner-overlay.sh" "${TARGET_ROOT}"

echo "[done] generated corporate demo output at ${TARGET_ROOT}"
