#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${ROOT}/codebase/target-generated"

echo "[stop] stopping parity snapshot stack"
docker compose -f "${TARGET}/docker-compose.yml" down
