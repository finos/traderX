#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="${ROOT}"

export CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-http://localhost:18093}"

generate_scripts=(
  "${ROOT}/pipeline/generate-reference-data-specfirst.sh"
  "${ROOT}/pipeline/generate-database-specfirst.sh"
  "${ROOT}/pipeline/generate-people-service-specfirst.sh"
  "${ROOT}/pipeline/generate-account-service-specfirst.sh"
  "${ROOT}/pipeline/generate-position-service-specfirst.sh"
  "${ROOT}/pipeline/generate-trade-feed-specfirst.sh"
  "${ROOT}/pipeline/generate-trade-processor-specfirst.sh"
  "${ROOT}/pipeline/generate-trade-service-specfirst.sh"
  "${ROOT}/pipeline/generate-web-front-end-angular-specfirst.sh"
)

test_scripts=(
  "${ROOT}/scripts/test-reference-data-overlay.sh"
  "${ROOT}/scripts/test-database-overlay.sh"
  "${ROOT}/scripts/test-people-service-overlay.sh"
  "${ROOT}/scripts/test-account-service-overlay.sh"
  "${ROOT}/scripts/test-position-service-overlay.sh"
  "${ROOT}/scripts/test-trade-feed-overlay.sh"
  "${ROOT}/scripts/test-trade-processor-overlay.sh"
  "${ROOT}/scripts/test-trade-service-overlay.sh"
  "${ROOT}/scripts/test-web-angular-overlay.sh"
)

"${ROOT}/pipeline/speckit/validate-speckit-readiness.sh"
"${ROOT}/pipeline/speckit/verify-spec-expressiveness.sh"

for script in "${generate_scripts[@]}"; do
  bash "${script}"
done

"${ROOT}/scripts/stop-base-uncontainerized-generated.sh" || true

cleanup() {
  if [[ "${TRADERSPEC_KEEP_RUNNING:-0}" != "1" ]]; then
    "${ROOT}/scripts/stop-base-uncontainerized-generated.sh" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS}" \
  "${ROOT}/scripts/start-base-uncontainerized-generated.sh"

for test_script in "${test_scripts[@]}"; do
  "${test_script}"
done

echo "[ok] full Spec Kit parity validation passed"
