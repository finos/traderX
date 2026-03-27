#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash TraderSpec/pipeline/speckit/compare-component-generation.sh <component-id> [legacy-ref]

Examples:
  bash TraderSpec/pipeline/speckit/compare-component-generation.sh reference-data HEAD
  bash TraderSpec/pipeline/speckit/compare-component-generation.sh trade-service origin/main

Notes:
  - <component-id> values:
      reference-data
      database
      people-service
      account-service
      position-service
      trade-feed
      trade-processor
      trade-service
      web-front-end-angular
  - [legacy-ref] defaults to HEAD.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

COMPONENT_ID="${1:-}"
LEGACY_REF="${2:-HEAD}"

if [[ -z "${COMPONENT_ID}" ]]; then
  usage
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${REPO_ROOT}"

case "${COMPONENT_ID}" in
  reference-data)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-reference-data-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/reference-data-specfirst"
    ;;
  database)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-database-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/database-specfirst"
    ;;
  people-service)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-people-service-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/people-service-specfirst"
    ;;
  account-service)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-account-service-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/account-service-specfirst"
    ;;
  position-service)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-position-service-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/position-service-specfirst"
    ;;
  trade-feed)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-trade-feed-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/trade-feed-specfirst"
    ;;
  trade-processor)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-trade-processor-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/trade-processor-specfirst"
    ;;
  trade-service)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-trade-service-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/trade-service-specfirst"
    ;;
  web-front-end-angular)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-web-front-end-angular-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/web-front-end-angular-specfirst"
    ;;
  *)
    echo "[fail] unsupported component-id: ${COMPONENT_ID}"
    usage
    exit 1
    ;;
esac

if [[ ! -f "${GENERATOR_SCRIPT}" ]]; then
  echo "[fail] missing generator script in current workspace: ${GENERATOR_SCRIPT}"
  exit 1
fi

TMP_DIR="$(mktemp -d /tmp/traderspec-compare-${COMPONENT_ID}-XXXXXX)"
LEGACY_WORKTREE="${TMP_DIR}/legacy-worktree"
LEGACY_OUT="${TMP_DIR}/legacy-output"
CURRENT_OUT="${TMP_DIR}/current-output"
DIFF_FILE="${TMP_DIR}/diff.patch"

cleanup() {
  git worktree remove --force "${LEGACY_WORKTREE}" >/dev/null 2>&1 || true
  rm -rf "${TMP_DIR}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git rev-parse --verify "${LEGACY_REF}^{commit}" >/dev/null 2>&1 || {
  echo "[fail] invalid git ref: ${LEGACY_REF}"
  exit 1
}

git worktree add --detach "${LEGACY_WORKTREE}" "${LEGACY_REF}" >/dev/null

if [[ ! -f "${LEGACY_WORKTREE}/${GENERATOR_SCRIPT}" ]]; then
  echo "[fail] legacy ref does not contain generator script: ${GENERATOR_SCRIPT}"
  exit 1
fi

echo "[run] legacy generator (${LEGACY_REF})"
bash "${LEGACY_WORKTREE}/${GENERATOR_SCRIPT}"

if [[ ! -d "${LEGACY_WORKTREE}/${GENERATED_DIR}" ]]; then
  echo "[fail] legacy generation did not create expected directory: ${GENERATED_DIR}"
  exit 1
fi

mkdir -p "${LEGACY_OUT}" "${CURRENT_OUT}"
cp -R "${LEGACY_WORKTREE}/${GENERATED_DIR}" "${LEGACY_OUT}/component"

echo "[run] current generator (working tree)"
bash "${GENERATOR_SCRIPT}"

if [[ ! -d "${GENERATED_DIR}" ]]; then
  echo "[fail] current generation did not create expected directory: ${GENERATED_DIR}"
  exit 1
fi

cp -R "${GENERATED_DIR}" "${CURRENT_OUT}/component"

set +e
diff -ru "${LEGACY_OUT}/component" "${CURRENT_OUT}/component" > "${DIFF_FILE}"
DIFF_EXIT=$?
set -e

if [[ "${DIFF_EXIT}" -eq 0 ]]; then
  echo "[ok] no output differences for ${COMPONENT_ID} (legacy=${LEGACY_REF} vs current)"
  exit 0
fi

if [[ "${DIFF_EXIT}" -eq 1 ]]; then
  echo "[diff] output differences detected for ${COMPONENT_ID}"
  echo "[diff] showing first 200 lines:"
  sed -n '1,200p' "${DIFF_FILE}"
  echo "[diff] full patch: ${DIFF_FILE}"
  exit 1
fi

echo "[fail] diff command error while comparing outputs"
exit 2
