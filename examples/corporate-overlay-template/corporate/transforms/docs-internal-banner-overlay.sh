#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${1:-${ROOT}/generated/code/target-generated}"
OUT_DIR="${TARGET_ROOT}/corp-overlays/corp-002-internal-docs-branding"
OUT_FILE="${OUT_DIR}/internal-docs-banner.config.json"

mkdir -p "${OUT_DIR}"

cat > "${OUT_FILE}" <<'EOF'
{
  "announcementBar": {
    "id": "internal-distribution-warning",
    "content": "INTERNAL DISTRIBUTION ONLY - CORPORATE OVERLAY",
    "backgroundColor": "#b00020",
    "textColor": "#ffffff",
    "isCloseable": false
  },
  "navbarBrandLabel": "TraderX Corporate Overlay"
}
EOF

echo "[ok] wrote internal docs branding overlay: ${OUT_FILE}"
