#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_COMPONENT_DIR="${ROOT}/generated/code/components/web-front-end-angular-specfirst"

[[ -d "${WEB_COMPONENT_DIR}" ]] || {
  echo "[fail] missing generated web component: ${WEB_COMPONENT_DIR}"
  echo "[hint] run bash pipeline/generate-web-front-end-angular-specfirst.sh first."
  exit 1
}

for env_file in \
  "${WEB_COMPONENT_DIR}/main/environments/environment.ts" \
  "${WEB_COMPONENT_DIR}/main/environments/environment.local.ts"; do
  cat <<'EOF' > "${env_file}"
// State 002 overlay: route browser traffic through edge proxy endpoint.
export const environment = {
    production:         false,
    accountUrl:         `//${window.location.host}/account-service`,
    refrenceDataUrl:    `//${window.location.host}/reference-data`,
    tradesUrl:          `//${window.location.host}/trade-service/trade/`,
    positionsUrl:       `//${window.location.host}/position-service`,
    peopleUrl:          `//${window.location.host}/people-service`,
    tradeFeedUrl:       `//${window.location.host}`
};
EOF
done

echo "[done] applied state 002 web overlay to ${WEB_COMPONENT_DIR}"
