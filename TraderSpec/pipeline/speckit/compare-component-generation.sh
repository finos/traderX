#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash TraderSpec/pipeline/speckit/compare-component-generation.sh <component-id> [legacy-ref] [--allow-differences]

Examples:
  bash TraderSpec/pipeline/speckit/compare-component-generation.sh reference-data HEAD
  bash TraderSpec/pipeline/speckit/compare-component-generation.sh trade-service origin/main
  bash TraderSpec/pipeline/speckit/compare-component-generation.sh trade-service HEAD --allow-differences

Notes:
  - <component-id> values:
      reference-data
      database
      people-service
      account-service
      position-service
      trade-feed
      trade-processor
      trade-service
      web-front-end-angular
  - [legacy-ref] defaults to HEAD.
  - Returns non-zero on differences unless --allow-differences is set.
EOF
}

semantic_category_for_path() {
  local path="$1"
  case "${path}" in
    README.md|*/README.md|SPEC.generated.md|*/SPEC.generated.md|SPEC.component.md|*/SPEC.component.md|SPEC.manifest.json|*/SPEC.manifest.json)
      echo "docs-spec"
      ;;
    openapi.yaml|*/openapi.yaml)
      echo "api-contract"
      ;;
    Dockerfile|*/Dockerfile|Dockerfile.prod|*/Dockerfile.prod|run.sh|*/run.sh|*.conf.template)
      echo "deployment-runtime"
      ;;
    build.gradle|*/build.gradle|settings.gradle|*/settings.gradle|gradlew|*/gradlew|gradlew.bat|*/gradlew.bat|package.json|*/package.json|angular.json|*/angular.json|tsconfig*.json|*/tsconfig*.json|*.csproj|*.sln|nest-cli.json|karma.conf.js|prettier.config.js)
      echo "build-tooling"
      ;;
    src/main/resources/application.properties|*/src/main/resources/application.properties|*/appsettings.json|*/appsettings.Development.json|*/Program.cs|*/main.ts|*/index.js|*/main/environments/*)
      echo "runtime-config"
      ;;
    */main/assets/*|*/assets/img/*)
      echo "branding-assets"
      ;;
    */data/*)
      echo "seed-data"
      ;;
    src/*|*/src/*|main/app/*|*/main/app/*)
      echo "source-code"
      ;;
    *)
      echo "other"
      ;;
  esac
}

parse_changed_paths() {
  local names_file="$1"
  local legacy_root="$2"
  local current_root="$3"

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue

    if [[ "${line}" == Files\ *\ and\ *\ differ ]]; then
      local left="${line#Files }"
      left="${left%% and *}"
      local path="${left#${legacy_root}/component/}"
      echo "${path}"
      continue
    fi

    if [[ "${line}" == Only\ in\ * ]]; then
      local rest="${line#Only in }"
      local dir="${rest%%:*}"
      local file="${rest#*: }"
      local rel_dir="${dir}"
      if [[ "${rel_dir}" == "${legacy_root}/component" ]]; then
        rel_dir=""
      elif [[ "${rel_dir}" == "${current_root}/component" ]]; then
        rel_dir=""
      elif [[ "${rel_dir}" == "${legacy_root}/component/"* ]]; then
        rel_dir="${rel_dir#${legacy_root}/component/}"
      elif [[ "${rel_dir}" == "${current_root}/component/"* ]]; then
        rel_dir="${rel_dir#${current_root}/component/}"
      fi

      if [[ -z "${rel_dir}" ]]; then
        echo "${file}"
      else
        echo "${rel_dir}/${file}"
      fi
    fi
  done < "${names_file}" | sort -u
}

print_semantic_summary() {
  local names_file="$1"
  local legacy_root="$2"
  local current_root="$3"

  local source_code_count=0
  local runtime_config_count=0
  local api_contract_count=0
  local build_tooling_count=0
  local deployment_runtime_count=0
  local seed_data_count=0
  local branding_assets_count=0
  local docs_spec_count=0
  local other_count=0
  local category

  while IFS= read -r changed_path; do
    [[ -n "${changed_path}" ]] || continue
    category="$(semantic_category_for_path "${changed_path}")"
    case "${category}" in
      source-code) source_code_count=$((source_code_count + 1)) ;;
      runtime-config) runtime_config_count=$((runtime_config_count + 1)) ;;
      api-contract) api_contract_count=$((api_contract_count + 1)) ;;
      build-tooling) build_tooling_count=$((build_tooling_count + 1)) ;;
      deployment-runtime) deployment_runtime_count=$((deployment_runtime_count + 1)) ;;
      seed-data) seed_data_count=$((seed_data_count + 1)) ;;
      branding-assets) branding_assets_count=$((branding_assets_count + 1)) ;;
      docs-spec) docs_spec_count=$((docs_spec_count + 1)) ;;
      *) other_count=$((other_count + 1)) ;;
    esac
  done < <(parse_changed_paths "${names_file}" "${legacy_root}" "${current_root}")

  echo "[semantic] diff category counts:"
  if (( source_code_count > 0 )); then echo "  - source-code: ${source_code_count}"; fi
  if (( runtime_config_count > 0 )); then echo "  - runtime-config: ${runtime_config_count}"; fi
  if (( api_contract_count > 0 )); then echo "  - api-contract: ${api_contract_count}"; fi
  if (( build_tooling_count > 0 )); then echo "  - build-tooling: ${build_tooling_count}"; fi
  if (( deployment_runtime_count > 0 )); then echo "  - deployment-runtime: ${deployment_runtime_count}"; fi
  if (( seed_data_count > 0 )); then echo "  - seed-data: ${seed_data_count}"; fi
  if (( branding_assets_count > 0 )); then echo "  - branding-assets: ${branding_assets_count}"; fi
  if (( docs_spec_count > 0 )); then echo "  - docs-spec: ${docs_spec_count}"; fi
  if (( other_count > 0 )); then echo "  - other: ${other_count}"; fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

COMPONENT_ID=""
LEGACY_REF="HEAD"
ALLOW_DIFFERENCES=0

while (($# > 0)); do
  case "$1" in
    --allow-differences)
      ALLOW_DIFFERENCES=1
      ;;
    *)
      if [[ -z "${COMPONENT_ID}" ]]; then
        COMPONENT_ID="$1"
      elif [[ "${LEGACY_REF}" == "HEAD" ]]; then
        LEGACY_REF="$1"
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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${REPO_ROOT}"

case "${COMPONENT_ID}" in
  reference-data)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-reference-data-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/reference-data-specfirst"
    ;;
  database)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-database-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/database-specfirst"
    ;;
  people-service)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-people-service-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/people-service-specfirst"
    ;;
  account-service)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-account-service-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/account-service-specfirst"
    ;;
  position-service)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-position-service-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/position-service-specfirst"
    ;;
  trade-feed)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-trade-feed-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/trade-feed-specfirst"
    ;;
  trade-processor)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-trade-processor-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/trade-processor-specfirst"
    ;;
  trade-service)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-trade-service-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/trade-service-specfirst"
    ;;
  web-front-end-angular)
    GENERATOR_SCRIPT="TraderSpec/pipeline/generate-web-front-end-angular-specfirst.sh"
    GENERATED_DIR="TraderSpec/codebase/generated-components/web-front-end-angular-specfirst"
    ;;
  *)
    echo "[fail] unsupported component-id: ${COMPONENT_ID}"
    usage
    exit 1
    ;;
esac

if [[ ! -f "${GENERATOR_SCRIPT}" ]]; then
  echo "[fail] missing generator script in current workspace: ${GENERATOR_SCRIPT}"
  exit 1
fi

TMP_DIR="$(mktemp -d /tmp/traderspec-compare-${COMPONENT_ID}-XXXXXX)"
LEGACY_WORKTREE="${TMP_DIR}/legacy-worktree"
LEGACY_OUT="${TMP_DIR}/legacy-output"
CURRENT_OUT="${TMP_DIR}/current-output"
DIFF_FILE="${TMP_DIR}/diff.patch"
DIFF_NAMES_FILE="${TMP_DIR}/diff.names"

cleanup() {
  git worktree remove --force "${LEGACY_WORKTREE}" >/dev/null 2>&1 || true
  rm -rf "${TMP_DIR}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git rev-parse --verify "${LEGACY_REF}^{commit}" >/dev/null 2>&1 || {
  echo "[fail] invalid git ref: ${LEGACY_REF}"
  exit 1
}

git worktree add --detach "${LEGACY_WORKTREE}" "${LEGACY_REF}" >/dev/null

if [[ ! -f "${LEGACY_WORKTREE}/${GENERATOR_SCRIPT}" ]]; then
  echo "[fail] legacy ref does not contain generator script: ${GENERATOR_SCRIPT}"
  exit 1
fi

echo "[run] legacy generator (${LEGACY_REF})"
bash "${LEGACY_WORKTREE}/${GENERATOR_SCRIPT}"

if [[ ! -d "${LEGACY_WORKTREE}/${GENERATED_DIR}" ]]; then
  echo "[fail] legacy generation did not create expected directory: ${GENERATED_DIR}"
  exit 1
fi

mkdir -p "${LEGACY_OUT}" "${CURRENT_OUT}"
cp -R "${LEGACY_WORKTREE}/${GENERATED_DIR}" "${LEGACY_OUT}/component"

echo "[run] current generator (working tree)"
bash "${GENERATOR_SCRIPT}"

if [[ ! -d "${GENERATED_DIR}" ]]; then
  echo "[fail] current generation did not create expected directory: ${GENERATED_DIR}"
  exit 1
fi

cp -R "${GENERATED_DIR}" "${CURRENT_OUT}/component"

set +e
diff -ru "${LEGACY_OUT}/component" "${CURRENT_OUT}/component" > "${DIFF_FILE}"
DIFF_EXIT=$?
diff -rq "${LEGACY_OUT}/component" "${CURRENT_OUT}/component" > "${DIFF_NAMES_FILE}"
DIFF_NAMES_EXIT=$?
set -e

if [[ "${DIFF_EXIT}" -eq 0 && "${DIFF_NAMES_EXIT}" -eq 0 ]]; then
  echo "[ok] no output differences for ${COMPONENT_ID} (legacy=${LEGACY_REF} vs current)"
  exit 0
fi

if [[ "${DIFF_EXIT}" -eq 1 || "${DIFF_NAMES_EXIT}" -eq 1 ]]; then
  echo "[diff] output differences detected for ${COMPONENT_ID}"
  print_semantic_summary "${DIFF_NAMES_FILE}" "${LEGACY_OUT}" "${CURRENT_OUT}"
  echo "[diff] showing first 200 lines:"
  sed -n '1,200p' "${DIFF_FILE}"
  echo "[diff] full patch: ${DIFF_FILE}"

  if (( ALLOW_DIFFERENCES == 1 )); then
    echo "[ok] differences allowed by flag --allow-differences"
    exit 0
  fi
  exit 1
fi

echo "[fail] diff command error while comparing outputs"
exit 2
