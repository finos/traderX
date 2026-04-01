#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="006-tilt-kubernetes-dev-loop"
PARENT_STATE_ID="004-kubernetes-runtime"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=006-tilt-kubernetes-dev-loop
[summary] parent-state=004-kubernetes-runtime
[summary] impacted-assets=tiltfile,tilt-settings,kubernetes-manifest-overlay
[summary] generated-path=generated/code/target-generated/tilt-kubernetes-dev-loop
[summary] runtime-entrypoint=./scripts/start-state-006-tilt-kubernetes-dev-loop-generated.sh
EOF
