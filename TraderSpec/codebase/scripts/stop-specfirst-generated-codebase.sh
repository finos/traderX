#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TARGET="${REPO_ROOT}/TraderSpec/codebase/target-generated-specfirst"

echo "[stop] stopping spec-first generated stack"
docker compose -f "${TARGET}/docker-compose.yml" down
