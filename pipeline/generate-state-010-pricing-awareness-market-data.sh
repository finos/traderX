#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="010-pricing-awareness-market-data"
PARENT_STATE_ID="007-messaging-nats-replacement"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
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
