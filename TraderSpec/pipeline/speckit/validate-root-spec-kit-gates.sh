#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

FEATURE_ID="${SPECKIT_FEATURE_ID:-001-baseline-uncontainerized-parity}"
FEATURE_DIR="${REPO_ROOT}/specs/${FEATURE_ID}"

fail() {
  echo "[fail] $*"
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "missing file: ${path}"
}

require_dir() {
  local path="$1"
  [[ -d "${path}" ]] || fail "missing dir: ${path}"
}

require_file "${REPO_ROOT}/.specify/memory/constitution.md"
require_file "${REPO_ROOT}/.specify/scripts/bash/check-prerequisites.sh"
require_file "${REPO_ROOT}/.specify/templates/spec-template.md"
require_file "${REPO_ROOT}/.specify/templates/plan-template.md"
require_file "${REPO_ROOT}/.specify/templates/tasks-template.md"

[[ "${SPECKIT_MODE}" == "root-feature" ]] || fail "expected root-feature mode, got ${SPECKIT_MODE} (root=${SPECKIT_ROOT})"
[[ "${SPECKIT_ROOT}" == "${FEATURE_DIR}" ]] || fail "expected SPECKIT_ROOT=${FEATURE_DIR}, got ${SPECKIT_ROOT}"

require_dir "${FEATURE_DIR}"
require_file "${FEATURE_DIR}/README.md"
require_file "${FEATURE_DIR}/spec.md"
require_file "${FEATURE_DIR}/plan.md"
require_file "${FEATURE_DIR}/tasks.md"
require_file "${FEATURE_DIR}/fidelity-profile.md"

require_dir "${FEATURE_DIR}/system"
require_file "${FEATURE_DIR}/system/system-context.md"
require_file "${FEATURE_DIR}/system/end-to-end-flows.md"
require_file "${FEATURE_DIR}/system/system-requirements.md"
require_file "${FEATURE_DIR}/system/user-stories.md"
require_file "${FEATURE_DIR}/system/acceptance-criteria.md"
require_file "${FEATURE_DIR}/system/requirements-traceability.csv"
require_file "${FEATURE_DIR}/system/component-generation-manifest.md"
require_file "${FEATURE_DIR}/system/component-generation-manifest.schema.json"

require_dir "${FEATURE_DIR}/components"
require_file "${FEATURE_DIR}/components/reference-data.md"
require_file "${FEATURE_DIR}/components/people-service.md"
require_file "${FEATURE_DIR}/components/account-service.md"
require_file "${FEATURE_DIR}/components/position-service.md"
require_file "${FEATURE_DIR}/components/trade-service.md"
require_file "${FEATURE_DIR}/components/trade-processor.md"

require_dir "${FEATURE_DIR}/contracts"
require_file "${FEATURE_DIR}/contracts/reference-data/openapi.yaml"
require_file "${FEATURE_DIR}/contracts/people-service/openapi.yaml"
require_file "${FEATURE_DIR}/contracts/account-service/openapi.yaml"
require_file "${FEATURE_DIR}/contracts/position-service/openapi.yaml"
require_file "${FEATURE_DIR}/contracts/trade-service/openapi.yaml"
require_file "${FEATURE_DIR}/contracts/trade-processor/openapi.yaml"

# Ensure branch resolution via explicit feature override works regardless of branch naming.
SPECIFY_FEATURE="${FEATURE_ID}" bash "${REPO_ROOT}/.specify/scripts/bash/check-prerequisites.sh" --json --include-tasks --require-tasks >/dev/null

# Validate no-override behavior based on branch naming convention.
branch_name="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"
if [[ "${branch_name}" =~ ^[0-9]{3}- ]] || [[ "${branch_name}" =~ ^[0-9]{8}-[0-9]{6}- ]]; then
  bash "${REPO_ROOT}/.specify/scripts/bash/check-prerequisites.sh" --json --include-tasks --require-tasks >/dev/null
else
  if bash "${REPO_ROOT}/.specify/scripts/bash/check-prerequisites.sh" --json --include-tasks --require-tasks >/dev/null 2>&1; then
    fail "expected check-prerequisites to fail on non-feature branch (${branch_name}) without SPECIFY_FEATURE override"
  fi
fi

# Legacy decommission guard: legacy TraderSpec/speckit docs should be pointer-only.
for legacy_dir in system components conformance; do
  extra_files="$(find "${ROOT}/speckit/${legacy_dir}" -maxdepth 1 -type f ! -name '_category_.json' ! -name 'README.md')"
  [[ -z "${extra_files}" ]] || fail "legacy ${legacy_dir} still contains non-pointer artifacts: ${extra_files}"
done

extra_contracts="$(find "${ROOT}/speckit/contracts" -type f ! -name '_category_.json' ! -name 'README.md')"
[[ -z "${extra_contracts}" ]] || fail "legacy contracts still contain non-pointer artifacts: ${extra_contracts}"

echo "[ok] root Spec Kit quality gates passed (feature=${FEATURE_ID}, branch=${branch_name})"
