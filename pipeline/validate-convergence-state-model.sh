#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"

if [[ ! -f "${CATALOG}" ]]; then
  echo "[fail] missing state catalog: ${CATALOG}"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq is required"
  exit 1
fi

errors=0

valid_level() {
  case "$1" in
    none|C0|C1|C2|C3) return 0 ;;
    *) return 1 ;;
  esac
}

valid_role() {
  case "$1" in
    prelude|canonical|optional) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r state_id; do
  [[ -n "${state_id}" ]] || continue
  previous_count="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | ((.previous // []) | length)' "${CATALOG}")"
  is_convergence="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | (.isConvergence // false)' "${CATALOG}")"
  level="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | (.convergenceLevel // "none")' "${CATALOG}")"
  role="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | (.primaryLineageRole // "canonical")' "${CATALOG}")"
  dotted_count="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | ((.dottedParents // []) | length)' "${CATALOG}")"

  if [[ "${previous_count}" -gt 1 ]]; then
    echo "[fail] ${state_id}: previous must contain at most 1 state"
    errors=$((errors + 1))
  fi

  if ! valid_level "${level}"; then
    echo "[fail] ${state_id}: invalid convergenceLevel=${level}"
    errors=$((errors + 1))
  fi

  if ! valid_role "${role}"; then
    echo "[fail] ${state_id}: invalid primaryLineageRole=${role}"
    errors=$((errors + 1))
  fi

  if [[ "${is_convergence}" != "true" && "${dotted_count}" -gt 0 ]]; then
    echo "[fail] ${state_id}: dottedParents are only allowed for convergence states"
    errors=$((errors + 1))
  fi

  if [[ "${is_convergence}" == "true" && "${level}" == "none" ]]; then
    echo "[fail] ${state_id}: convergence state must set convergenceLevel to C0/C1/C2/C3"
    errors=$((errors + 1))
  fi

  if [[ "${is_convergence}" != "true" && "${level}" != "none" ]]; then
    echo "[fail] ${state_id}: non-convergence state must use convergenceLevel=none"
    errors=$((errors + 1))
  fi

  while IFS= read -r dotted; do
    [[ -n "${dotted}" ]] || continue
    if ! jq -e --arg dotted "${dotted}" '.states[] | select(.id == $dotted)' "${CATALOG}" >/dev/null; then
      echo "[fail] ${state_id}: dotted parent does not exist: ${dotted}"
      errors=$((errors + 1))
    fi
  done < <(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | (.dottedParents // [])[]?' "${CATALOG}")

  if [[ "${is_convergence}" == "true" ]]; then
    feature_pack="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | .featurePack' "${CATALOG}")"
    rationale_file="${ROOT}/${feature_pack}/system/convergence-rationale.md"
    if [[ ! -f "${rationale_file}" ]]; then
      echo "[fail] ${state_id}: missing required convergence rationale file: ${rationale_file}"
      errors=$((errors + 1))
    fi
  fi
done < <(jq -r '.states[].id' "${CATALOG}")

if ((errors > 0)); then
  echo "[fail] convergence state-model validation failed (${errors} issue(s))"
  exit 1
fi

echo "[ok] convergence state-model validation passed"
