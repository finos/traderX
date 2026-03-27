#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEMO_DIR="${ROOT}/states/03-service-mesh/solo-demo"

[[ -d "${DEMO_DIR}" ]] || { echo "missing solo-demo"; exit 1; }
[[ -d "${DEMO_DIR}/manifests" ]] || { echo "missing manifests"; exit 1; }
[[ -d "${DEMO_DIR}/scripts" ]] || { echo "missing scripts"; exit 1; }
[[ -d "${DEMO_DIR}/observability" ]] || { echo "missing observability"; exit 1; }

"${DEMO_DIR}/scripts/verify.sh"

echo "[verify] 03-service-mesh checks passed"
