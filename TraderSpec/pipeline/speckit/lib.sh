#!/usr/bin/env bash
set -euo pipefail

TRADERSPEC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPECKIT_ROOT="${TRADERSPEC_ROOT}/speckit"
SPECKIT_MATRIX="${SPECKIT_ROOT}/system/requirements-traceability.csv"
SPECKIT_COMPONENT_CSV="${TRADERSPEC_ROOT}/catalog/component-spec.csv"

speckit_assert_global_readiness() {
  local required=(
    "${SPECKIT_ROOT}/README.md"
    "${SPECKIT_ROOT}/system/system-context.md"
    "${SPECKIT_ROOT}/system/end-to-end-flows.md"
    "${SPECKIT_ROOT}/system/system-requirements.md"
    "${SPECKIT_ROOT}/system/user-stories.md"
    "${SPECKIT_ROOT}/system/acceptance-criteria.md"
    "${SPECKIT_ROOT}/system/component-generation-manifest.md"
    "${SPECKIT_ROOT}/system/component-generation-manifest.schema.json"
    "${SPECKIT_MATRIX}"
  )

  local file
  for file in "${required[@]}"; do
    [[ -f "${file}" ]] || {
      echo "[fail] missing Spec Kit artifact: ${file}"
      return 1
    }
  done

  for flow_id in F1 F2 F3 F4 F5 F6 STARTUP; do
    if ! rg -q "${flow_id}" "${SPECKIT_ROOT}/system/end-to-end-flows.md" "${SPECKIT_MATRIX}"; then
      echo "[fail] missing flow mapping for ${flow_id} in Spec Kit artifacts"
      return 1
    fi
  done
}

speckit_list_generated_components() {
  awk -F, 'NR > 1 && $3 ~ /generated-components\// { print $1 }' "${SPECKIT_COMPONENT_CSV}"
}

speckit_assert_component_ready() {
  local component_id="$1"
  local component_spec="${SPECKIT_ROOT}/components/${component_id}.md"

  [[ -f "${component_spec}" ]] || {
    echo "[fail] missing component Spec Kit file: ${component_spec}"
    return 1
  }

  if ! awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id { found = 1 } END { exit(found ? 0 : 1) }' "${SPECKIT_MATRIX}"; then
    echo "[fail] no traceability entries for component ${component_id} in ${SPECKIT_MATRIX}"
    return 1
  fi
}
