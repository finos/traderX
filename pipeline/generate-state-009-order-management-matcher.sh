#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="009-order-management-matcher"
PARENT_STATE_ID="008-pricing-awareness-market-data"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/render-state-009-order-management-matcher.sh"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOT'
[summary] state=009-order-management-matcher
[summary] parent-state=008-pricing-awareness-market-data
[summary] track=functional
[summary] impacted-assets=order-management,order-matcher,admin-ui,order-blotter-live-pricing,order-observability-metrics,dashboards
[summary] generated-path=generated/code/target-generated/order-management-matcher
[summary] runtime-entrypoint=./scripts/start-state-009-order-management-matcher-generated.sh
EOT
