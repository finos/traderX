#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="${ROOT}"
CSV="${ROOT}/catalog/component-spec.csv"
source "${ROOT}/pipeline/speckit/lib.sh"

required_specs=(
  "${SPECKIT_SYSTEM_DIR}/system-context.md"
  "${SPECKIT_SYSTEM_DIR}/end-to-end-flows.md"
  "${SPECKIT_SYSTEM_DIR}/system-requirements.md"
  "${SPECKIT_SYSTEM_DIR}/user-stories.md"
  "${SPECKIT_SYSTEM_DIR}/acceptance-criteria.md"
  "${SPECKIT_SYSTEM_DIR}/requirements-traceability.csv"
  "${SPECKIT_SYSTEM_DIR}/component-generation-manifest.md"
)

for f in "${required_specs[@]}"; do
  [[ -f "${f}" ]] || { echo "[missing-spec] ${f}"; exit 1; }
done

[[ -f "${CSV}" ]] || { echo "[missing-spec] ${CSV}"; exit 1; }
"${ROOT}/pipeline/speckit/validate-speckit-readiness.sh"

row=0
services=0

while IFS=, read -r component_id kind source_path target_path language framework build_tool default_port contract_file depends_on required_env notes; do
  row=$((row + 1))
  if ((row == 1)); then
    continue
  fi

  [[ -n "${component_id}" ]] || { echo "[fail] empty component_id on row ${row}"; exit 1; }
  [[ -n "${kind}" ]] || { echo "[fail] empty kind for ${component_id}"; exit 1; }
  [[ -n "${source_path}" ]] || { echo "[fail] empty source_path for ${component_id}"; exit 1; }
  [[ -n "${target_path}" ]] || { echo "[fail] empty target_path for ${component_id}"; exit 1; }
  [[ -n "${language}" ]] || { echo "[fail] empty language for ${component_id}"; exit 1; }
  [[ -n "${framework}" ]] || { echo "[fail] empty framework for ${component_id}"; exit 1; }

  if [[ "${contract_file}" != "none" && ! -f "${REPO_ROOT}/${contract_file}" ]]; then
    echo "[fail] contract file missing for ${component_id}: ${contract_file}"
    exit 1
  fi

  if [[ "${kind}" == "service" ]]; then
    services=$((services + 1))
    if [[ ! "${default_port}" =~ ^[0-9]+$ ]]; then
      echo "[fail] invalid default_port for ${component_id}: ${default_port}"
      exit 1
    fi
  fi
done < "${CSV}"

components=$((row - 1))
echo "[ok] regeneration readiness validated (${components} components, ${services} services)"
