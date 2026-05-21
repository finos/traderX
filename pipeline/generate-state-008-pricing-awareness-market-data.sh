#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
TARGET_FRONTEND_DIR="${TARGET_ROOT}/web-front-end/angular"
FRONTEND_OVERRIDE_SOURCE_DIR="${ROOT}/specs/008-pricing-awareness-market-data/generation/frontend-overrides/web-front-end/angular"
STATE_ID="008-pricing-awareness-market-data"
PARENT_STATE_ID="007-observability-lgtm-compose"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
if [[ -d "${FRONTEND_OVERRIDE_SOURCE_DIR}" ]]; then
  cp -R "${FRONTEND_OVERRIDE_SOURCE_DIR}/." "${TARGET_FRONTEND_DIR}/"
else
  echo "[fail] frontend override source not found: ${FRONTEND_OVERRIDE_SOURCE_DIR}"
  exit 1
fi
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=008-pricing-awareness-market-data
[summary] parent-state=007-observability-lgtm-compose
[summary] impacted-components=trade-service,trade-processor,position-service,web-front-end-angular,price-publisher,database,ingress
[summary] added-component=price-publisher
[summary] impacted-assets=pricing-stream-subjects,trade-price-stamping,position-cost-basis-aggregation,portfolio-valuation-ui
[summary] generated-path=generated/code/target-generated/pricing-awareness-market-data
[summary] runtime-entrypoint=./scripts/start-state-008-pricing-awareness-market-data-generated.sh
EOF
