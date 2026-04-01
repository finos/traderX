#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="002-edge-proxy-uncontainerized"
PARENT_STATE_ID="001-baseline-uncontainerized-parity"
COMPONENTS_ROOT="${ROOT}/generated/code/components"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}" "${COMPONENTS_ROOT}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=002-edge-proxy-uncontainerized
[summary] impacted-components=edge-proxy,web-front-end-angular
[summary] runtime-entrypoint=./scripts/start-state-002-edge-proxy-generated.sh
EOF
