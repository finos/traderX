#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="${ROOT}"
CSV="${ROOT}/catalog/component-spec.csv"

source "${ROOT}/pipeline/speckit/lib.sh"

MATRIX="${SPECKIT_MATRIX}"
REQ_DOC="${SPECKIT_SYSTEM_DIR}/system-requirements.md"
STORY_DOC="${SPECKIT_SYSTEM_DIR}/user-stories.md"
AC_DOC="${SPECKIT_SYSTEM_DIR}/acceptance-criteria.md"

speckit_assert_global_readiness
[[ -f "${CSV}" ]] || { echo "[fail] missing component catalog: ${CSV}"; exit 1; }
[[ -f "${MATRIX}" ]] || { echo "[fail] missing traceability matrix: ${MATRIX}"; exit 1; }

for flow_id in STARTUP F1 F2 F3 F4 F5 F6; do
  if ! awk -F, -v flow_id="${flow_id}" 'NR > 1 && $4 == flow_id { found = 1 } END { exit(found ? 0 : 1) }' "${MATRIX}"; then
    echo "[fail] no traceability rows for flow ${flow_id}"
    exit 1
  fi
done

while IFS= read -r req_id; do
  [[ -n "${req_id}" ]] || continue
  if ! awk -F, -v req_id="${req_id}" 'NR > 1 && $1 == req_id { found = 1 } END { exit(found ? 0 : 1) }' "${MATRIX}"; then
    echo "[fail] requirement ${req_id} is not mapped in traceability matrix"
    exit 1
  fi
done < <(rg -o 'SYS-(FR|NFR)-[0-9]{3}' "${REQ_DOC}" | sort -u)

while IFS= read -r story_id; do
  [[ -n "${story_id}" ]] || continue
  if ! awk -F, -v story_id="${story_id}" 'NR > 1 && $2 == story_id { found = 1 } END { exit(found ? 0 : 1) }' "${MATRIX}"; then
    echo "[fail] story ${story_id} is not mapped in traceability matrix"
    exit 1
  fi
done < <(rg -o 'US-[0-9]{3}' "${STORY_DOC}" | sort -u)

while IFS= read -r acceptance_id; do
  [[ -n "${acceptance_id}" ]] || continue
  if ! awk -F, -v acceptance_id="${acceptance_id}" 'NR > 1 && $3 == acceptance_id { found = 1 } END { exit(found ? 0 : 1) }' "${MATRIX}"; then
    echo "[fail] acceptance criteria ${acceptance_id} is not mapped in traceability matrix"
    exit 1
  fi
done < <(rg -o 'AC-[0-9]{3}' "${AC_DOC}" | sort -u)

row=0
components=0

while IFS=, read -r component_id kind source_path target_path language framework build_tool default_port contract_file depends_on required_env notes; do
  row=$((row + 1))
  if ((row == 1)); then
    continue
  fi

  speckit_assert_component_ready "${component_id}"

  if ! awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id && $7 != "" { found = 1 } END { exit(found ? 0 : 1) }' "${MATRIX}"; then
    echo "[fail] no verification references mapped for component ${component_id}"
    exit 1
  fi

  while IFS= read -r verification_ref; do
    [[ -n "${verification_ref}" ]] || continue
    if [[ ! -e "${REPO_ROOT}/${verification_ref}" ]]; then
      echo "[fail] verification reference does not exist for ${component_id}: ${verification_ref}"
      exit 1
    fi
  done < <(awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id { print $7 }' "${MATRIX}" | sort -u)

  if [[ "${contract_file}" != "none" ]]; then
    contract_path="${REPO_ROOT}/${contract_file}"
    [[ -f "${contract_path}" ]] || {
      echo "[fail] missing mapped contract file for ${component_id}: ${contract_file}"
      exit 1
    }

    generated_contract="${REPO_ROOT}/${source_path}/openapi.yaml"
    if [[ -f "${generated_contract}" ]]; then
      if ! diff -q "${generated_contract}" "${contract_path}" >/dev/null 2>&1; then
        echo "[fail] contract mismatch for ${component_id}:"
        echo "       generated=${generated_contract}"
        echo "       speckit=${contract_path}"
        exit 1
      fi
    fi
  fi

  components=$((components + 1))
done < "${CSV}"

echo "[ok] Spec Kit expressiveness parity checks passed (${components} components)"
