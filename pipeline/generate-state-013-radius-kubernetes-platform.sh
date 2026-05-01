#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="013-radius-kubernetes-platform"
PARENT_STATE_ID="012-platform-convergence-c3"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/render-state-013-radius-kubernetes-platform.sh"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=013-radius-kubernetes-platform
[summary] parent-state=012-platform-convergence-c3
[summary] impacted-assets=radius-app-model,radius-workspace,bicep-extension-config
[summary] generated-path=generated/code/target-generated/radius-kubernetes-platform
[summary] runtime-entrypoint=./scripts/start-state-013-radius-kubernetes-platform-generated.sh
EOF
