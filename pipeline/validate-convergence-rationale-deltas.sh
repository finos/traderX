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

if ! git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[info] not a git work tree; skipping convergence-rationale delta gate"
  exit 0
fi

BASE_REF="${SPEC_GATES_BASE_REF:-}"
if [[ -z "${BASE_REF}" ]]; then
  for candidate in origin/main main origin/master master; do
    if git -C "${ROOT}" rev-parse --verify "${candidate}" >/dev/null 2>&1; then
      BASE_REF="${candidate}"
      break
    fi
  done
fi

if [[ -z "${BASE_REF}" ]]; then
  echo "[info] no base ref found; skipping convergence-rationale delta gate"
  exit 0
fi

if ! git -C "${ROOT}" cat-file -e "${BASE_REF}:catalog/state-catalog.json" >/dev/null 2>&1; then
  echo "[info] base ref ${BASE_REF} has no catalog/state-catalog.json; skipping convergence-rationale delta gate"
  exit 0
fi

changed_files="$(git -C "${ROOT}" diff --name-only "${BASE_REF}...HEAD" || true)"
errors=0

state_object_from_base() {
  local state_id="$1"
  git -C "${ROOT}" show "${BASE_REF}:catalog/state-catalog.json" \
    | jq -c --arg id "${state_id}" '.states[]? | select(.id == $id)'
}

while IFS= read -r state_id; do
  [[ -n "${state_id}" ]] || continue

  feature_pack="$(jq -r --arg id "${state_id}" '.states[] | select(.id == $id) | .featurePack' "${CATALOG}")"
  rationale_rel="${feature_pack}/system/convergence-rationale.md"

  current_state_obj="$(jq -c --arg id "${state_id}" '.states[] | select(.id == $id)' "${CATALOG}")"
  base_state_obj="$(state_object_from_base "${state_id}")"
  metadata_changed=0
  if [[ "${current_state_obj}" != "${base_state_obj}" ]]; then
    metadata_changed=1
  fi

  rationale_changed=0
  if printf '%s\n' "${changed_files}" | grep -Fx "${rationale_rel}" >/dev/null 2>&1; then
    rationale_changed=1
  fi

  pack_content_changed=0
  if printf '%s\n' "${changed_files}" \
    | grep -E "^${feature_pack}/" \
    | grep -Fvx "${rationale_rel}" >/dev/null 2>&1; then
    pack_content_changed=1
  fi

  if (( metadata_changed == 1 || pack_content_changed == 1 )); then
    if (( rationale_changed == 0 )); then
      echo "[fail] ${state_id}: convergence metadata/content changed without rationale update (${rationale_rel})"
      errors=$((errors + 1))
    fi
  fi
done < <(jq -r '.states[] | select((.isConvergence // false) == true) | .id' "${CATALOG}")

if (( errors > 0 )); then
  echo "[fail] convergence-rationale delta validation failed (${errors} issue(s))"
  exit 1
fi

echo "[ok] convergence-rationale delta validation passed (base=${BASE_REF})"
