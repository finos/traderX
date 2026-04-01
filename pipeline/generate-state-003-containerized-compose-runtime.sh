#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="003-containerized-compose-runtime"
PARENT_STATE_ID="002-edge-proxy-uncontainerized"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=003-containerized-compose-runtime
[summary] impacted-components=database,reference-data,trade-feed,people-service,account-service,position-service,trade-processor,trade-service,web-front-end-angular,ingress
[summary] impacted-assets=containerized-compose,dockerfile.compose,ingress-nginx-template
[summary] runtime-entrypoint=./scripts/start-state-003-containerized-generated.sh
EOF
