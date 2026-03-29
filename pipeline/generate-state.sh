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
    cat <<'EOF'
[summary] state=002-edge-proxy-uncontainerized
[summary] impacted-components=edge-proxy,web-front-end-angular
[summary] runtime-entrypoint=./scripts/start-state-002-edge-proxy-generated.sh
EOF
    ;;
  003-containerized-compose-runtime)
    bash "${ROOT}/pipeline/generate-state.sh" 002-edge-proxy-uncontainerized
    bash "${ROOT}/pipeline/generate-state-003-compose-assets.sh"
    cat <<'EOF'
[summary] state=003-containerized-compose-runtime
[summary] impacted-components=database,reference-data,trade-feed,people-service,account-service,position-service,trade-processor,trade-service,web-front-end-angular,edge-proxy
[summary] impacted-assets=containerized-compose,dockerfile.compose
[summary] runtime-entrypoint=./scripts/start-state-003-containerized-generated.sh
EOF
    ;;
  *)
    echo "[fail] unsupported state-id: ${STATE_ID}"
    exit 1
    ;;
esac
