#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRADERX_RUN_CLEANUP="${TRADERX_RUN_CLEANUP:-0}"

if [[ "${TRADERX_RUN_CLEANUP}" == "1" ]]; then
  "${SCRIPT_DIR}/cleanup.sh" "$@"
fi

"${SCRIPT_DIR}/deploy.sh" "$@"
