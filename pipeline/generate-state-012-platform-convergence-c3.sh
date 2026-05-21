#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="012-platform-convergence-c3"
PARENT_STATE_ID="011-tilt-kubernetes-dev-loop"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=012-platform-convergence-c3
[summary] parent-state=011-tilt-kubernetes-dev-loop
[summary] type=convergence-checkpoint
[summary] impacted-assets=state-lineage-metadata,convergence-docs
[summary] generated-path=generated/code/target-generated/tilt-kubernetes-dev-loop
[summary] runtime-entrypoint=./scripts/start-state-012-platform-convergence-c3-generated.sh
EOF
