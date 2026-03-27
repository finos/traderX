#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

echo "[stop] stopping current TraderX stack"
docker compose -f "${REPO_ROOT}/docker-compose.yml" down
