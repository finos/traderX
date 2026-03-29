#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

[[ -f "${ROOT}/specs/001-baseline-uncontainerized-parity/spec.md" ]] || { echo "missing baseline feature spec"; exit 1; }
[[ -f "${ROOT}/catalog/base-uncontainerized-processes.csv" ]] || { echo "missing baseline process catalog"; exit 1; }
[[ -x "${ROOT}/scripts/start-base-uncontainerized-generated.sh" ]] || { echo "missing generated start script"; exit 1; }
[[ -x "${ROOT}/scripts/stop-base-uncontainerized-generated.sh" ]] || { echo "missing generated stop script"; exit 1; }

echo "[verify] 00-monolith baseline checks passed"
