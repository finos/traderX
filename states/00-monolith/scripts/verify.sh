#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

[[ -f "${ROOT}/docker-compose.yml" ]] || { echo "missing docker-compose.yml"; exit 1; }
[[ -d "${ROOT}/trade-service" ]] || { echo "missing trade-service"; exit 1; }
[[ -d "${ROOT}/account-service" ]] || { echo "missing account-service"; exit 1; }

echo "[verify] 00-monolith baseline checks passed"
