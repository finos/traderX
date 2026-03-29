#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "${ROOT}/foundation/00-traditional-to-cloud-native/specs/10-base-uncontainerized-state.md" ]] || { echo "missing baseline foundation spec"; exit 1; }
[[ -x "${ROOT}/scripts/start-base-uncontainerized-generated.sh" ]] || { echo "missing generated start script"; exit 1; }
[[ -x "${ROOT}/scripts/stop-base-uncontainerized-generated.sh" ]] || { echo "missing generated stop script"; exit 1; }
[[ -x "${ROOT}/scripts/status-base-uncontainerized-generated.sh" ]] || { echo "missing generated status script"; exit 1; }

echo "[ok] codebase scaffold verification passed"
