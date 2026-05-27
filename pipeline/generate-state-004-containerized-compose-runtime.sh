#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
STATE_ID="004-containerized-compose-runtime"
PARENT_STATE_ID="003-agentic-harness-foundation"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
WEB_FRONTEND_ROOT="${TARGET_ROOT}/web-front-end/angular"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
# Parent harness installation may create compatibility symlinks under
# target-generated/generated/code/components; clear them so the 004 patchset
# can apply deterministic link definitions without add/add conflicts.
rm -rf "${TARGET_ROOT}/generated/code/components"
# Parent state wrappers are intentionally rewritten by the 004+ lineage; remove
# inherited env wrappers so patch add operations stay conflict-free.
rm -f \
  "${TARGET_ROOT}/start-env.sh" \
  "${TARGET_ROOT}/status-env.sh" \
  "${TARGET_ROOT}/stop-env.sh" \
  "${TARGET_ROOT}/test-env.sh"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"

# State 004+ deployment targets should not run Angular dev server (Vite HMR)
# inside container images. Force compose builds to use the production/static
# image contract by aligning Dockerfile.compose with Dockerfile.prod.
if [[ -f "${WEB_FRONTEND_ROOT}/Dockerfile.prod" ]]; then
  cp "${WEB_FRONTEND_ROOT}/Dockerfile.prod" "${WEB_FRONTEND_ROOT}/Dockerfile.compose"
fi

bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=004-containerized-compose-runtime
[summary] impacted-components=database,reference-data,trade-feed,people-service,account-service,position-service,trade-processor,trade-service,web-front-end-angular,ingress
[summary] impacted-assets=containerized-compose,dockerfile.compose,ingress-nginx-template
[summary] runtime-entrypoint=./scripts/start-state-004-containerized-generated.sh
EOF
