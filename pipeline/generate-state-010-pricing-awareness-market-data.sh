#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="010-pricing-awareness-market-data"
PARENT_STATE_ID="007-messaging-nats-replacement"
TARGET="${ROOT}/generated/code/target-generated"
OVERLAY_DIR="${ROOT}/templates/state-010-pricing-awareness-market-data-overlay"
STATE_DIR="${TARGET}/pricing-awareness-market-data"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"

[[ -d "${TARGET}" ]] || {
  echo "[fail] missing target output: ${TARGET}"
  exit 1
}

[[ -d "${OVERLAY_DIR}" ]] || {
  echo "[fail] missing overlay template directory: ${OVERLAY_DIR}"
  exit 1
}

cp -R "${OVERLAY_DIR}/." "${TARGET}/"

# State 010 is published as its own runtime assembly directory.
rm -rf "${TARGET}/messaging-nats-replacement"

[[ -f "${STATE_DIR}/docker-compose.yml" ]] || {
  echo "[fail] missing state compose file: ${STATE_DIR}/docker-compose.yml"
  exit 1
}

[[ -f "${TARGET}/price-publisher/src/main.js" ]] || {
  echo "[fail] missing generated price-publisher component"
  exit 1
}

bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=010-pricing-awareness-market-data
[summary] parent-state=007-messaging-nats-replacement
[summary] impacted-components=trade-service,trade-processor,position-service,web-front-end-angular,price-publisher,database,ingress
[summary] added-component=price-publisher
[summary] impacted-assets=pricing-stream-subjects,trade-price-stamping,position-cost-basis-aggregation,portfolio-valuation-ui
[summary] generated-path=generated/code/target-generated/pricing-awareness-market-data
[summary] runtime-entrypoint=./scripts/start-state-010-pricing-awareness-market-data-generated.sh
EOF
