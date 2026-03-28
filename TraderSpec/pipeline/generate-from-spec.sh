#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
CSV="${ROOT}/catalog/component-spec.csv"
TARGET="${ROOT}/codebase/target-generated-specfirst"
MANIFEST_DIR="${ROOT}/codebase/generated-manifests"
source "${ROOT}/pipeline/speckit/lib.sh"

"${ROOT}/pipeline/validate-regeneration-readiness.sh"
bash "${ROOT}/pipeline/speckit/compile-all-component-manifests.sh"

rm -rf "${TARGET}"
mkdir -p "${TARGET}/apps" "${TARGET}/contracts" "${TARGET}/metadata"

cat <<'EOF' > "${TARGET}/README.md"
# TraderSpec Generated (Spec-First)

This tree is generated from TraderSpec requirements and component technical specs.
It is intentionally produced from specification inputs rather than copied source code.
EOF

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

row=0
while IFS=, read -r component_id kind source_path target_path language framework build_tool default_port contract_file depends_on required_env notes; do
  row=$((row + 1))
  if ((row == 1)); then
    continue
  fi

  component_dir="${TARGET}/${target_path}"
  src="${REPO_ROOT}/${source_path}"
  if [[ ! -d "${src}" ]]; then
    echo "[fail] missing synthesized component source for ${component_id}: ${src}"
    exit 1
  fi
  mkdir -p "$(dirname "${component_dir}")"
  cp -R "${src}" "${component_dir}"

  component_spec="${SPECKIT_COMPONENTS_DIR}/${component_id}.md"
  if [[ -f "${component_spec}" ]]; then
    cp "${component_spec}" "${component_dir}/SPEC.component.md"
  fi

  component_manifest="${MANIFEST_DIR}/${component_id}.manifest.json"
  if [[ -f "${component_manifest}" ]]; then
    cp "${component_manifest}" "${component_dir}/SPEC.manifest.json"
  fi

  if [[ "${contract_file}" != "none" ]]; then
    mkdir -p "${TARGET}/contracts/${component_id}"
    cp "${REPO_ROOT}/${contract_file}" "${TARGET}/contracts/${component_id}/openapi.yaml"
  fi

  echo "${component_id},${kind},${target_path},${default_port}" >> "${TARGET}/metadata/component-index.csv"
done < "${CSV}"

cp "${REPO_ROOT}/docker-compose.yml" "${TARGET}/docker-compose.yml"

echo "[done] generated spec-first scaffold at ${TARGET}"
