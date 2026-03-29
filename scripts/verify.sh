#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "${ROOT}/specs/001-baseline-uncontainerized-parity/system/system-context.md" ]] || { echo "missing baseline system context"; exit 1; }
[[ -f "${ROOT}/specs/001-baseline-uncontainerized-parity/system/system-requirements.md" ]] || { echo "missing baseline system requirements"; exit 1; }
[[ -x "${ROOT}/scripts/start-base-uncontainerized-generated.sh" ]] || { echo "missing generated start script"; exit 1; }
[[ -x "${ROOT}/scripts/stop-base-uncontainerized-generated.sh" ]] || { echo "missing generated stop script"; exit 1; }
[[ -x "${ROOT}/scripts/status-base-uncontainerized-generated.sh" ]] || { echo "missing generated status script"; exit 1; }
[[ -x "${ROOT}/pipeline/generate-state.sh" ]] || { echo "missing state-aware generation script"; exit 1; }
[[ -x "${ROOT}/scripts/start-state-002-edge-proxy-generated.sh" ]] || { echo "missing state 002 start script"; exit 1; }

echo "[ok] codebase scaffold verification passed"
