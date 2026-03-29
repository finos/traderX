#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

required=(
  "${ROOT}/catalog/learning-paths.yaml"
  "${ROOT}/catalog/component-spec.csv"
  "${SPECKIT_SYSTEM_DIR}/system-context.md"
  "${SPECKIT_SYSTEM_DIR}/end-to-end-flows.md"
  "${SPECKIT_SYSTEM_DIR}/system-requirements.md"
  "${SPECKIT_SYSTEM_DIR}/user-stories.md"
  "${SPECKIT_SYSTEM_DIR}/acceptance-criteria.md"
  "${SPECKIT_SYSTEM_DIR}/requirements-traceability.csv"
  "${SPECKIT_SYSTEM_DIR}/component-generation-manifest.md"
  "${SPECKIT_SYSTEM_DIR}/architecture.md"
  "${ROOT}/tracks/devex/path.md"
  "${ROOT}/tracks/nonfunctional/path.md"
  "${ROOT}/tracks/functional/path.md"
)

for file in "${required[@]}"; do
  [[ -f "${file}" ]] || { echo "[missing] ${file}"; exit 1; }
done

step_specs_count="$(find "${ROOT}/tracks" -type f -name "spec.md" | wc -l | tr -d ' ')"
if [[ "${step_specs_count}" -lt 20 ]]; then
  echo "[fail] expected at least 20 step specs, found ${step_specs_count}"
  exit 1
fi

"${ROOT}/pipeline/validate-regeneration-readiness.sh"
"${ROOT}/pipeline/speckit/validate-speckit-readiness.sh"
"${ROOT}/pipeline/speckit/verify-spec-expressiveness.sh"

echo "[ok] TraderSpec coverage checks passed (${step_specs_count} step specs)"
