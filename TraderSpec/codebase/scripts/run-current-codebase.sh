#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

echo "[run] starting current TraderX stack from repo root compose"
docker compose -f "${REPO_ROOT}/docker-compose.yml" up -d --build

cat <<'EOF'
[run] started
UI (via ingress): http://localhost:8080
Angular service direct: http://localhost:18093
EOF
