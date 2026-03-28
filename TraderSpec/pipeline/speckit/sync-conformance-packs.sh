#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/pipeline/speckit/lib.sh"

OUT_DIR="${SPECKIT_CONFORMANCE_DIR}"
MATRIX="${SPECKIT_MATRIX}"

speckit_assert_global_readiness
mkdir -p "${OUT_DIR}"

write_list() {
  local values="$1"
  if [[ -z "${values}" ]]; then
    echo "- none"
    return
  fi

  while IFS= read -r value; do
    [[ -n "${value}" ]] || continue
    echo "- \`${value}\`"
  done <<< "${values}"
}

while IFS= read -r component_id; do
  [[ -n "${component_id}" ]] || continue

  requirements="$(awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id { print $1 }' "${MATRIX}" | sort -u)"
  stories="$(awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id { print $2 }' "${MATRIX}" | sort -u)"
  acceptance="$(awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id { print $3 }' "${MATRIX}" | sort -u)"
  flows="$(awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id { print $4 }' "${MATRIX}" | sort -u)"
  contracts="$(awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id && $6 != "none" { print $6 }' "${MATRIX}" | sort -u)"
  verification_refs="$(awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id { print $7 }' "${MATRIX}" | sort -u)"

  fr_requirements="$(printf "%s\n" "${requirements}" | rg '^SYS-FR-' || true)"
  nfr_requirements="$(printf "%s\n" "${requirements}" | rg '^SYS-NFR-' || true)"

  out_file="${OUT_DIR}/${component_id}.md"

  {
    echo "# ${component_id} Conformance Pack"
    echo
    echo "This pack defines requirement and verification gates for \`${component_id}\`."
    echo
    echo "## User Stories"
    write_list "${stories}"
    echo
    echo "## Functional Requirements"
    write_list "${fr_requirements}"
    echo
    echo "## Non-Functional Requirements"
    write_list "${nfr_requirements}"
    echo
    echo "## Acceptance Criteria"
    write_list "${acceptance}"
    echo
    echo "## Flows"
    write_list "${flows}"
    echo
    echo "## Contract Gates"
    write_list "${contracts}"
    echo
    echo "## Verification References"
    write_list "${verification_refs}"
  } > "${out_file}"

  echo "[ok] wrote ${out_file}"
done < <(speckit_list_generated_components)

echo "[ok] conformance packs synced in ${OUT_DIR}"
