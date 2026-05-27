#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
TARGET_FRONTEND_DIR="${TARGET_ROOT}/web-front-end/angular"
FRONTEND_OVERRIDE_SOURCE_DIR="${ROOT}/specs/008-pricing-awareness-market-data/generation/frontend-overrides/web-front-end/angular"
STATE_ID="008-pricing-awareness-market-data"
PARENT_STATE_ID="007-observability-lgtm-compose"

normalize_parent_messaging_compose_for_patch() {
  local compose_file="${TARGET_ROOT}/messaging-nats-replacement/docker-compose.yml"
  [[ -f "${compose_file}" ]] || return 0

  # Keep parent compose shape stable across nested generation depths so the
  # 008 patch applies deterministically.
  perl -0pi -e 's/CORS_ALLOWED_ORIGINS: "http:\/\/localhost:8080"/CORS_ALLOWED_ORIGINS: "\$\{CORS_ALLOWED_ORIGINS:-\*\}"/g' "${compose_file}"
  perl -0pi -e 's/NGINX_HOST: "localhost"/NGINX_HOST: "\$\{TRADERX_FQDN:-localhost\}"/g' "${compose_file}"
}

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
normalize_parent_messaging_compose_for_patch
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/render-state-008-pricing-awareness-market-data.sh"
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
