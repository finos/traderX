#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
CSV="${ROOT}/catalog/component-spec.csv"
TARGET="${ROOT}/codebase/target-generated-specfirst"
SPECKIT_MATRIX="${ROOT}/speckit/system/requirements-traceability.csv"
MANIFEST_DIR="${ROOT}/codebase/generated-manifests"
HYDRATE_FROM_SOURCE="${1:-}"

"${ROOT}/pipeline/validate-regeneration-readiness.sh"
bash "${ROOT}/pipeline/speckit/compile-all-component-manifests.sh"

rm -rf "${TARGET}"
mkdir -p "${TARGET}/apps" "${TARGET}/contracts" "${TARGET}/metadata"

cat <<'EOF' > "${TARGET}/README.md"
# TraderSpec Generated (Spec-First)

This tree is generated from TraderSpec requirements and component technical specs.
It is intentionally produced from specification inputs rather than copied source code.
EOF

row=0
if [[ "${HYDRATE_FROM_SOURCE}" == "--hydrate-from-source" ]]; then
  echo "[mode] hydrate-from-source enabled (spec-mapped materialization)"
fi

while IFS=, read -r component_id kind source_path target_path language framework build_tool default_port contract_file depends_on required_env notes; do
  row=$((row + 1))
  if ((row == 1)); then
    continue
  fi

  component_dir="${TARGET}/${target_path}"
  if [[ "${HYDRATE_FROM_SOURCE}" == "--hydrate-from-source" ]]; then
    src="${REPO_ROOT}/${source_path}"
    if [[ -d "${src}" ]]; then
      mkdir -p "$(dirname "${component_dir}")"
      cp -R "${src}" "${component_dir}"
    else
      mkdir -p "${component_dir}/src" "${component_dir}/tests"
    fi
  else
    mkdir -p "${component_dir}/src" "${component_dir}/tests"
  fi

  cat <<EOF > "${component_dir}/SPEC.generated.md"
# ${component_id}

- kind: ${kind}
- sourcePath: ${source_path}
- language: ${language}
- framework: ${framework}
- buildTool: ${build_tool}
- defaultPort: ${default_port}
- dependsOn: ${depends_on}
- requiredEnv: ${required_env}

Notes:
${notes}
EOF

  component_spec="${ROOT}/speckit/components/${component_id}.md"
  if [[ -f "${component_spec}" ]]; then
    cp "${component_spec}" "${component_dir}/SPEC.component.md"
  fi

  component_manifest="${MANIFEST_DIR}/${component_id}.manifest.json"
  if [[ -f "${component_manifest}" ]]; then
    cp "${component_manifest}" "${component_dir}/SPEC.manifest.json"
  fi

  if [[ -f "${SPECKIT_MATRIX}" ]]; then
    {
      echo ""
      echo "SpecKit Traceability:"
      awk -F, -v component_id="${component_id}" 'NR > 1 && $5 == component_id {printf "- requirement=%s story=%s acceptance=%s flow=%s\n", $1, $2, $3, $4}' "${SPECKIT_MATRIX}"
    } >> "${component_dir}/SPEC.generated.md"
  fi

  if [[ "${contract_file}" != "none" ]]; then
    mkdir -p "${TARGET}/contracts/${component_id}"
    cp "${REPO_ROOT}/${contract_file}" "${TARGET}/contracts/${component_id}/openapi.yaml"
  fi

  echo "${component_id},${kind},${target_path},${default_port}" >> "${TARGET}/metadata/component-index.csv"
done < "${CSV}"

cp "${REPO_ROOT}/docker-compose.yml" "${TARGET}/docker-compose.yml"

echo "[done] generated spec-first scaffold at ${TARGET}"
