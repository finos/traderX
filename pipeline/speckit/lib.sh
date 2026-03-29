#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRADERSPEC_ROOT="${REPO_ROOT}/TraderSpec"

SPECKIT_FEATURE_ID="${SPECKIT_FEATURE_ID:-001-baseline-uncontainerized-parity}"
SPECKIT_FEATURE_ROOT="${REPO_ROOT}/specs/${SPECKIT_FEATURE_ID}"
SPECKIT_LEGACY_ROOT="${TRADERSPEC_ROOT}/speckit"

if [[ -d "${SPECKIT_FEATURE_ROOT}" ]]; then
  SPECKIT_ROOT="${SPECKIT_FEATURE_ROOT}"
  SPECKIT_MODE="root-feature"
elif [[ -d "${SPECKIT_LEGACY_ROOT}" ]]; then
  SPECKIT_ROOT="${SPECKIT_LEGACY_ROOT}"
  SPECKIT_MODE="legacy-traderspec"
else
  SPECKIT_ROOT="${SPECKIT_FEATURE_ROOT}"
  SPECKIT_MODE="missing"
fi

SPECKIT_SYSTEM_DIR="${SPECKIT_ROOT}/system"
SPECKIT_COMPONENTS_DIR="${SPECKIT_ROOT}/components"
SPECKIT_CONTRACTS_DIR="${SPECKIT_ROOT}/contracts"
SPECKIT_CONFORMANCE_DIR="${SPECKIT_ROOT}/conformance"
SPECKIT_MATRIX="${SPECKIT_SYSTEM_DIR}/requirements-traceability.csv"
SPECKIT_COMPONENT_CSV="${REPO_ROOT}/catalog/component-spec.csv"

speckit_has_rg() {
  command -v rg >/dev/null 2>&1
}

speckit_pattern_exists() {
  local pattern="$1"
  shift
  if speckit_has_rg; then
    rg -q -- "${pattern}" "$@"
  else
    grep -Eq -- "${pattern}" "$@"
  fi
}

speckit_extract_pattern() {
  local pattern="$1"
  local file="$2"
  if speckit_has_rg; then
    rg -o -- "${pattern}" "${file}"
  else
    grep -Eo -- "${pattern}" "${file}"
  fi
}

speckit_filter_stdin_regex() {
  local pattern="$1"
  if speckit_has_rg; then
    rg -- "${pattern}" || true
  else
    grep -E -- "${pattern}" || true
  fi
}

speckit_file_contains_literal() {
  local literal="$1"
  local file="$2"
  if speckit_has_rg; then
    rg -Fq -- "${literal}" "${file}"
  else
    grep -Fq -- "${literal}" "${file}"
  fi
}

speckit_echo_context() {
  echo "[info] Spec Kit mode=${SPECKIT_MODE} root=${SPECKIT_ROOT}"
  if ! speckit_has_rg; then
    echo "[info] ripgrep not found; using grep fallback for Spec Kit checks"
  fi
}

speckit_assert_global_readiness() {
  local required=(
    "${SPECKIT_SYSTEM_DIR}/system-context.md"
    "${SPECKIT_SYSTEM_DIR}/end-to-end-flows.md"
    "${SPECKIT_SYSTEM_DIR}/system-requirements.md"
    "${SPECKIT_SYSTEM_DIR}/user-stories.md"
    "${SPECKIT_SYSTEM_DIR}/acceptance-criteria.md"
    "${SPECKIT_SYSTEM_DIR}/component-generation-manifest.md"
    "${SPECKIT_SYSTEM_DIR}/component-generation-manifest.schema.json"
    "${SPECKIT_MATRIX}"
  )

  if [[ ! -d "${SPECKIT_ROOT}" ]]; then
    echo "[fail] Spec Kit root not found: ${SPECKIT_ROOT}"
    return 1
  fi

  local file
  for file in "${required[@]}"; do
    [[ -f "${file}" ]] || {
      echo "[fail] missing Spec Kit artifact: ${file}"
      return 1
    }
  done

  for flow_id in F1 F2 F3 F4 F5 F6 STARTUP; do
    if ! speckit_pattern_exists "${flow_id}" "${SPECKIT_SYSTEM_DIR}/end-to-end-flows.md" "${SPECKIT_MATRIX}"; then
      echo "[fail] missing flow mapping for ${flow_id} in Spec Kit artifacts"
      return 1
    fi
  done
}

speckit_list_generated_components() {
  awk -F, 'NR > 1 && $3 ~ /generated\/code\/components\// { print $1 }' "${SPECKIT_COMPONENT_CSV}"
}

speckit_assert_component_ready() {
  local component_id="$1"
  local component_spec="${SPECKIT_COMPONENTS_DIR}/${component_id}.md"

  [[ -f "${component_spec}" ]] || {
    echo "[fail] missing component Spec Kit file: ${component_spec}"
    return 1
  }

  if ! awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id { found = 1 } END { exit(found ? 0 : 1) }' "${SPECKIT_MATRIX}"; then
    echo "[fail] no traceability entries for component ${component_id} in ${SPECKIT_MATRIX}"
    return 1
  fi
}
