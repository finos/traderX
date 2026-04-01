#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="005-radius-kubernetes-platform"
PARENT_STATE_ID="004-kubernetes-runtime"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=005-radius-kubernetes-platform
[summary] parent-state=004-kubernetes-runtime
[summary] impacted-assets=radius-app-model,radius-workspace,bicep-extension-config
[summary] generated-path=generated/code/target-generated/radius-kubernetes-platform
[summary] runtime-entrypoint=./scripts/start-state-005-radius-kubernetes-platform-generated.sh
EOF
