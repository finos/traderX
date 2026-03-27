#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${ROOT}/codebase/target-generated"

"${ROOT}/codebase/scripts/prepare-parity-layout.sh"

echo "[run] starting parity snapshot from ${TARGET}"
docker compose -f "${TARGET}/docker-compose.yml" up -d --build

cat <<'EOF'
[run] parity snapshot started
UI (via ingress): http://localhost:8080
Angular service direct: http://localhost:18093
EOF
