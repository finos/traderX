#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${1:-${ROOT}/generated/code/target-generated}"
OUT_DIR="${TARGET_ROOT}/custom-overlays/custom-002-internal-docs-branding"
OUT_FILE="${OUT_DIR}/internal-docs-banner.config.json"

mkdir -p "${OUT_DIR}"

cat > "${OUT_FILE}" <<'EOF2'
{
  "announcementBar": {
    "id": "internal-distribution-warning",
    "content": "INTERNAL DISTRIBUTION ONLY - CUSTOM OVERLAY",
    "backgroundColor": "#b00020",
    "textColor": "#ffffff",
    "isCloseable": false
  },
  "navbarBrandLabel": "TraderX Internal Overlay"
}
EOF2

echo "[ok] wrote internal docs branding overlay: ${OUT_FILE}"
