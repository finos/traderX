#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="006-messaging-nats-replacement"
PARENT_STATE_ID="005-postgres-database-replacement"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
RUNTIME_OVERRIDES_ROOT="${ROOT}/specs/${STATE_ID}/generation/runtime-overrides"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
if [[ -d "${RUNTIME_OVERRIDES_ROOT}" ]]; then
  rsync -a "${RUNTIME_OVERRIDES_ROOT}/" "${TARGET_ROOT}/"
fi
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=006-messaging-nats-replacement
[summary] parent-state=005-postgres-database-replacement
[summary] impacted-components=trade-service,trade-processor,web-front-end-angular,ingress
[summary] replaced-component=trade-feed -> nats-broker
[summary] impacted-assets=compose-runtime,ingress-ws-route,nats-client-wiring
[summary] generated-path=generated/code/target-generated/messaging-nats-replacement
[summary] runtime-entrypoint=./scripts/start-state-006-messaging-nats-replacement-generated.sh
EOF
