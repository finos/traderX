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
)

for file in "${required[@]}"; do
  [[ -f "${file}" ]] || { echo "[missing] ${file}"; exit 1; }
done

state_specs_count="$(find "${ROOT}/specs" -maxdepth 2 -type f -name "spec.md" | wc -l | tr -d ' ')"
if [[ "${state_specs_count}" -lt 3 ]]; then
  echo "[fail] expected at least 3 state specs, found ${state_specs_count}"
  exit 1
fi

"${ROOT}/pipeline/validate-regeneration-readiness.sh"
"${ROOT}/pipeline/speckit/validate-speckit-readiness.sh"
"${ROOT}/pipeline/speckit/verify-spec-expressiveness.sh"

echo "[ok] Spec coverage checks passed (${state_specs_count} state specs)"
