#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash TraderSpec/pipeline/speckit/run-component-conformance-pack.sh <component-id> [--execute-runtime-checks]
EOF
}

COMPONENT_ID=""
EXECUTE_RUNTIME_CHECKS=0

while (($# > 0)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --execute-runtime-checks)
      EXECUTE_RUNTIME_CHECKS=1
      ;;
    *)
      if [[ -z "${COMPONENT_ID}" ]]; then
        COMPONENT_ID="$1"
      else
        echo "[fail] unexpected argument: $1"
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ -z "${COMPONENT_ID}" ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

MATRIX="${SPECKIT_MATRIX}"
CSV="${ROOT}/catalog/component-spec.csv"
PACK_FILE="${SPECKIT_CONFORMANCE_DIR}/${COMPONENT_ID}.md"
MANIFEST_PATH="${ROOT}/codebase/generated-manifests/${COMPONENT_ID}.manifest.json"

normalize_field() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ "${value}" == \"*\" ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf "%s" "${value}"
}

normalize_lines() {
  local values="$1"
  if [[ -z "${values}" ]]; then
    return
  fi
  printf "%s\n" "${values}" | tr -d '\r' | sed '/^$/d'
}

count_lines() {
  local values="$1"
  if [[ -z "${values}" ]]; then
    echo 0
    return
  fi
  printf "%s\n" "${values}" | sed '/^$/d' | wc -l | tr -d '[:space:]'
}

speckit_assert_global_readiness
speckit_assert_component_ready "${COMPONENT_ID}"

if [[ ! -f "${PACK_FILE}" ]]; then
  echo "[fail] missing conformance pack file: ${PACK_FILE}"
  echo "[hint] run: bash TraderSpec/pipeline/speckit/sync-conformance-packs.sh"
  exit 1
fi

component_row="$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $1 == component_id { print; exit }' "${CSV}")"
if [[ -z "${component_row}" ]]; then
  echo "[fail] component not found in catalog: ${COMPONENT_ID}"
  exit 1
fi

IFS=, read -r _component_id _kind source_path _rest <<< "${component_row}"
source_path="$(normalize_field "${source_path}")"

bash "${ROOT}/pipeline/speckit/compile-component-manifest.sh" "${COMPONENT_ID}" "${MANIFEST_PATH}"

requirements="$(normalize_lines "$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $1 }' "${MATRIX}" | sort -u)")"
stories="$(normalize_lines "$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $2 }' "${MATRIX}" | sort -u)")"
acceptance="$(normalize_lines "$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $3 }' "${MATRIX}" | sort -u)")"
verification_refs="$(normalize_lines "$(awk -F, -v component_id="${COMPONENT_ID}" 'NR > 1 && $5 == component_id { print $7 }' "${MATRIX}" | sort -u)")"

fr_requirements="$(printf "%s\n" "${requirements}" | rg '^SYS-FR-' || true)"
nfr_requirements="$(printf "%s\n" "${requirements}" | rg '^SYS-NFR-' || true)"

fr_count="$(count_lines "${fr_requirements}")"
nfr_count="$(count_lines "${nfr_requirements}")"
story_count="$(count_lines "${stories}")"
acceptance_count="$(count_lines "${acceptance}")"

if (( fr_count == 0 )); then
  echo "[fail] no functional requirements mapped for ${COMPONENT_ID}"
  exit 1
fi

if (( story_count == 0 )); then
  echo "[fail] no user stories mapped for ${COMPONENT_ID}"
  exit 1
fi

if (( acceptance_count == 0 )); then
  echo "[fail] no acceptance criteria mapped for ${COMPONENT_ID}"
  exit 1
fi

for id_group in "${requirements}" "${stories}" "${acceptance}"; do
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    if ! rg -Fq -- "${id}" "${PACK_FILE}"; then
      echo "[fail] conformance pack ${PACK_FILE} does not reference mapped id ${id}"
      exit 1
    fi
  done <<< "${id_group}"
done

contract_path="$(jq -r '.contracts.primary // ""' "${MANIFEST_PATH}")"
if [[ -n "${contract_path}" ]]; then
  if [[ ! -f "${REPO_ROOT}/${contract_path}" ]]; then
    echo "[fail] mapped contract does not exist: ${contract_path}"
    exit 1
  fi

  generated_contract="${REPO_ROOT}/${source_path}/openapi.yaml"
  if [[ -f "${generated_contract}" ]]; then
    if ! diff -q "${generated_contract}" "${REPO_ROOT}/${contract_path}" >/dev/null 2>&1; then
      echo "[fail] contract mismatch for ${COMPONENT_ID}"
      echo "       generated=${generated_contract}"
      echo "       expected=${REPO_ROOT}/${contract_path}"
      exit 1
    fi
  fi
fi

runtime_executed=0
runtime_skipped=0
verification_count=0

while IFS= read -r verification_ref; do
  [[ -n "${verification_ref}" ]] || continue
  verification_count=$((verification_count + 1))

  verification_path="${REPO_ROOT}/${verification_ref}"
  if [[ ! -e "${verification_path}" ]]; then
    echo "[fail] verification reference missing: ${verification_ref}"
    exit 1
  fi

  if (( EXECUTE_RUNTIME_CHECKS == 1 )) && [[ "${verification_ref}" == TraderSpec/codebase/scripts/test-*.sh ]]; then
    "${verification_path}"
    runtime_executed=$((runtime_executed + 1))
  else
    runtime_skipped=$((runtime_skipped + 1))
  fi
done <<< "${verification_refs}"

echo "[ok] conformance pack passed for ${COMPONENT_ID}"
echo "[info] FR=${fr_count} NFR=${nfr_count} stories=${story_count} acceptance=${acceptance_count} verification_refs=${verification_count} runtime_executed=${runtime_executed} runtime_skipped=${runtime_skipped}"
