#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="012-observability-on-pricing"
PARENT_STATE_ID="010-pricing-awareness-market-data"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOT'
[summary] state=012-observability-on-pricing
[summary] parent-state=010-pricing-awareness-market-data
[summary] impacted-assets=compose-runtime,lgtm-stack,pricing-observability-dashboards,prometheus-pricing-probes
[summary] generated-path=generated/code/target-generated/observability-on-pricing
[summary] runtime-entrypoint=./scripts/start-state-012-observability-on-pricing-generated.sh
EOT
