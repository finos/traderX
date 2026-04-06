#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="009-kubernetes-runtime"
PARENT_STATE_ID="008-order-management-matcher"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/render-state-009-kubernetes-runtime.sh"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=009-kubernetes-runtime
[summary] parent-state=008-order-management-matcher
[summary] impacted-components=database,nats-broker,reference-data,people-service,account-service,position-service,trade-processor,trade-service,price-publisher,order-matcher,web-front-end-angular,edge-proxy
[summary] impacted-assets=kubernetes-manifests,kind-cluster-config,image-build-plan
[summary] generated-path=generated/code/target-generated/kubernetes-runtime
[summary] runtime-entrypoint=./scripts/start-state-009-kubernetes-runtime-generated.sh
EOF
