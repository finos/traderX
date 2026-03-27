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

echo "[ok] TraderSpec coverage checks passed (${step_specs_count} step specs)"
