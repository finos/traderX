#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

[[ -f "${ROOT}/states/02-containerized/README.md" ]] || { echo "missing state README"; exit 1; }
[[ -f "${ROOT}/tracks/devex/steps/02-docker-compose/spec.md" ]] || { echo "missing devex docker-compose track spec"; exit 1; }
[[ -f "${ROOT}/docs/traderspec/visual-learning-graphs.md" ]] || { echo "missing learning graph doc"; exit 1; }
[[ -x "${ROOT}/scripts/start-base-uncontainerized-generated.sh" ]] || { echo "missing generated baseline start script"; exit 1; }

echo "[verify] 02-containerized checks passed"
