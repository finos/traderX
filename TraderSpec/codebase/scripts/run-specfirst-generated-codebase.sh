#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TRADERSPEC_ROOT="${REPO_ROOT}/TraderSpec"
TARGET="${TRADERSPEC_ROOT}/codebase/target-generated-specfirst"

"${TRADERSPEC_ROOT}/pipeline/generate-from-spec.sh" --hydrate-from-source
"${TRADERSPEC_ROOT}/codebase/scripts/prepare-specfirst-layout.sh"

echo "[run] starting spec-first generated codebase from ${TARGET}"
docker compose -f "${TARGET}/docker-compose.yml" up -d --build

cat <<'EOF'
[run] started
UI (via ingress): http://localhost:8080
Angular service direct: http://localhost:18093
EOF
