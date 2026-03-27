#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  "${ROOT}/foundation/00-traditional-to-cloud-native/specs/01-functional-requirements-baseline.md"
  "${ROOT}/foundation/00-traditional-to-cloud-native/specs/02-nfr-baseline.md"
  "${ROOT}/foundation/00-traditional-to-cloud-native/specs/05-functional-requirements-detailed.md"
  "${ROOT}/foundation/00-traditional-to-cloud-native/specs/06-technical-specifications.md"
  "${ROOT}/foundation/00-traditional-to-cloud-native/specs/07-ui-requirements-detailed.md"
  "${ROOT}/foundation/00-traditional-to-cloud-native/specs/08-requirements-traceability-matrix.md"
  "${ROOT}/foundation/00-traditional-to-cloud-native/specs/09-regeneration-strategy.md"
  "${ROOT}/catalog/learning-paths.yaml"
  "${ROOT}/catalog/component-spec.csv"
  "${ROOT}/speckit/system/system-context.md"
  "${ROOT}/speckit/system/end-to-end-flows.md"
  "${ROOT}/speckit/system/system-requirements.md"
  "${ROOT}/speckit/system/user-stories.md"
  "${ROOT}/speckit/system/acceptance-criteria.md"
  "${ROOT}/speckit/system/requirements-traceability.csv"
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
