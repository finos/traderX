#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="007-messaging-nats-replacement"
PARENT_STATE_ID="003-containerized-compose-runtime"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=007-messaging-nats-replacement
[summary] parent-state=003-containerized-compose-runtime
[summary] impacted-components=trade-service,trade-processor,web-front-end-angular,ingress
[summary] replaced-component=trade-feed -> nats-broker
[summary] impacted-assets=compose-runtime,ingress-ws-route,nats-client-wiring
[summary] generated-path=generated/code/target-generated/messaging-nats-replacement
[summary] runtime-entrypoint=./scripts/start-state-007-messaging-nats-replacement-generated.sh
EOF
