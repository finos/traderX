#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="${ROOT}"
CSV="${ROOT}/catalog/component-spec.csv"
MANIFEST_DIR="${ROOT}/generated/manifests"
COMPONENTS_DIR="${ROOT}/generated/code/components"

"${ROOT}/pipeline/validate-regeneration-readiness.sh"
bash "${ROOT}/pipeline/speckit/compile-all-component-manifests.sh"
mkdir -p "${MANIFEST_DIR}" "${COMPONENTS_DIR}"

# Ensure generated component sources are refreshed before assembling the target.
component_generators=(
  "generate-database-specfirst.sh"
  "generate-reference-data-specfirst.sh"
  "generate-trade-feed-specfirst.sh"
  "generate-people-service-specfirst.sh"
  "generate-account-service-specfirst.sh"
  "generate-position-service-specfirst.sh"
  "generate-trade-processor-specfirst.sh"
  "generate-trade-service-specfirst.sh"
  "generate-web-front-end-angular-specfirst.sh"
)

for generator in "${component_generators[@]}"; do
  bash "${ROOT}/pipeline/${generator}"
done

INDEX_OUT="${MANIFEST_DIR}/component-index.csv"
echo "component_id,kind,source_path,default_port,contract_file" > "${INDEX_OUT}"

row=0
while IFS=, read -r component_id kind source_path target_path language framework build_tool default_port contract_file depends_on required_env notes; do
  row=$((row + 1))
  if ((row == 1)); then
    continue
  fi

  source_dir="${REPO_ROOT}/${source_path}"
  if [[ ! -d "${source_dir}" ]]; then
    echo "[fail] missing synthesized component source for ${component_id}: ${source_dir}"
    exit 1
  fi
  echo "${component_id},${kind},${source_path},${default_port},${contract_file}" >> "${INDEX_OUT}"
done < "${CSV}"

echo "[done] generated components from spec into ${COMPONENTS_DIR}"
echo "[done] generated component index at ${INDEX_OUT}"
