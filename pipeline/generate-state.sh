#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="${1:-}"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/generate-state.sh <state-id>"
  echo "example: bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized"
  exit 1
fi

case "${STATE_ID}" in
  001-baseline-uncontainerized-parity)
    bash "${ROOT}/pipeline/generate-from-spec.sh"
    bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"
    cat <<'EOF'
[summary] state=001-baseline-uncontainerized-parity
[summary] impacted-components=database,reference-data,trade-feed,people-service,account-service,position-service,trade-processor,trade-service,web-front-end-angular
[summary] runtime-entrypoint=./scripts/start-base-uncontainerized-generated.sh
EOF
    ;;
  002-edge-proxy-uncontainerized)
    bash "${ROOT}/pipeline/generate-from-spec.sh"
    bash "${ROOT}/pipeline/generate-edge-proxy-specfirst.sh"
    bash "${ROOT}/pipeline/apply-state-002-web-overlay.sh"
    bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"
    cat <<'EOF'
[summary] state=002-edge-proxy-uncontainerized
[summary] impacted-components=edge-proxy,web-front-end-angular
[summary] runtime-entrypoint=./scripts/start-state-002-edge-proxy-generated.sh
EOF
    ;;
  003-containerized-compose-runtime)
    bash "${ROOT}/pipeline/generate-state.sh" 002-edge-proxy-uncontainerized
    bash "${ROOT}/pipeline/generate-state-003-compose-assets.sh"
    bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"
    cat <<'EOF'
[summary] state=003-containerized-compose-runtime
[summary] impacted-components=database,reference-data,trade-feed,people-service,account-service,position-service,trade-processor,trade-service,web-front-end-angular,ingress
[summary] impacted-assets=containerized-compose,dockerfile.compose,ingress-nginx-template
[summary] runtime-entrypoint=./scripts/start-state-003-containerized-generated.sh
EOF
    ;;
  004-kubernetes-runtime)
    bash "${ROOT}/pipeline/generate-state-004-kubernetes-runtime.sh"
    cat <<'EOF'
[summary] state=004-kubernetes-runtime
[summary] impacted-components=database,reference-data,trade-feed,people-service,account-service,position-service,trade-processor,trade-service,web-front-end-angular,edge-proxy
[summary] impacted-assets=kubernetes-manifests,kind-cluster-config,image-build-plan
[summary] generated-path=generated/code/target-generated/kubernetes-runtime
[summary] runtime-entrypoint=./scripts/start-state-004-kubernetes-generated.sh
EOF
    ;;
  *)
    HOOK="${ROOT}/pipeline/generate-state-${STATE_ID}.sh"
    if [[ -x "${HOOK}" ]]; then
      bash "${HOOK}"
    else
      echo "[fail] unsupported state-id: ${STATE_ID}"
      echo "[hint] add a state hook at ${HOOK} or implement explicit case logic."
      exit 1
    fi
    ;;
esac

bash "${ROOT}/pipeline/generate-state-docs-from-catalog.sh"
