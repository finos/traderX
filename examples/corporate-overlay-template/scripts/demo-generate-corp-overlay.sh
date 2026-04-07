#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_ROOT="${ROOT}/upstream/traderX"
STATE_ID="${1:-003-containerized-compose-runtime}"
TARGET_ROOT="${ROOT}/generated/code/target-generated"

if [[ ! -d "${UPSTREAM_ROOT}" ]]; then
  echo "[fail] upstream submodule not found at ${UPSTREAM_ROOT}"
  echo "[hint] run: git submodule update --init --recursive"
  exit 1
fi

echo "[info] generating upstream state ${STATE_ID}"
bash "${UPSTREAM_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"

mkdir -p "${TARGET_ROOT}"
rsync -a --delete "${UPSTREAM_ROOT}/generated/code/target-generated/" "${TARGET_ROOT}/"

echo "[info] applying corporate transforms"
bash "${ROOT}/corporate/transforms/managed-postgres-endpoint-overlay.sh" "${TARGET_ROOT}" "${STATE_ID}"
bash "${ROOT}/corporate/transforms/docs-internal-banner-overlay.sh" "${TARGET_ROOT}"

echo "[done] generated corporate demo output at ${TARGET_ROOT}"
