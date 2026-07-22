#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"

STATE_ID=""
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
COMPONENTS_ROOT="${GENERATED_ROOT}/code/components"

SKIP_CVE_SCAN="${TRADERX_SKIP_CVE_SCAN:-0}"
SKIP_LICENSE_SCAN="${TRADERX_SKIP_LICENSE_SCAN:-0}"
SKIP_CONTAINER_BUILD="${TRADERX_SKIP_CONTAINER_BUILD_PREFLIGHT:-0}"
SKIP_BRANCH_CONSISTENCY="${TRADERX_SKIP_BRANCH_DEPENDENCY_CONSISTENCY:-0}"
SKIP_COMPILE_PREFLIGHT="${TRADERX_SKIP_COMPILE_PREFLIGHT:-0}"
ALLOW_MISSING_BRANCHES="${TRADERX_ALLOW_MISSING_GENERATED_BRANCHES:-1}"

CVSS_THRESHOLD="${TRADERX_CVE_FAIL_ON_CVSS:-5}"
DEPENDENCY_CHECK_IMAGE="${TRADERX_DEPENDENCY_CHECK_IMAGE:-owasp/dependency-check:latest}"
DEPENDENCY_CHECK_DATA_DIR="${TRADERX_DEPENDENCY_CHECK_DATA_DIR:-${HOME}/.cache/traderx/dependency-check}"
DEPENDENCY_CHECK_NO_UPDATE="${TRADERX_DEPENDENCY_CHECK_NO_UPDATE:-0}"

usage() {
  cat <<'USAGE'
usage: bash pipeline/prepublish-generated-state-gate.sh <state-id> [--target-root <dir>] [--components-root <dir>] [--skip-compile-preflight] [--skip-cve-scan] [--skip-license-scan] [--skip-container-build] [--skip-branch-consistency] [--allow-missing-branches]

Runs pre-branch-generation gates that mirror generated-branch CI intent.

Defaults:
- CVE scan: enabled
- Node license scan: enabled
- Docker image build preflight: enabled
- generated-branch dependency consistency: enabled (allow-missing-branches=true)
- Set TRADERX_DEPENDENCY_CHECK_NO_UPDATE=1 to reuse an existing Dependency-Check data directory without NVD updates.
USAGE
}

fail() {
  echo "[fail] $*"
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "required command not found: ${cmd}"
}

while (($# > 0)); do
  case "$1" in
    --target-root)
      TARGET_ROOT="${2:-}"
      [[ -n "${TARGET_ROOT}" ]] || fail "--target-root requires a value"
      shift 2
      ;;
    --components-root)
      COMPONENTS_ROOT="${2:-}"
      [[ -n "${COMPONENTS_ROOT}" ]] || fail "--components-root requires a value"
      shift 2
      ;;
    --skip-cve-scan)
      SKIP_CVE_SCAN=1
      shift
      ;;
    --skip-compile-preflight)
      SKIP_COMPILE_PREFLIGHT=1
      shift
      ;;
    --skip-license-scan)
      SKIP_LICENSE_SCAN=1
      shift
      ;;
    --skip-container-build)
      SKIP_CONTAINER_BUILD=1
      shift
      ;;
    --skip-branch-consistency)
      SKIP_BRANCH_CONSISTENCY=1
      shift
      ;;
    --allow-missing-branches)
      ALLOW_MISSING_BRANCHES=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -* )
      fail "unknown arg: $1"
      ;;
    *)
      if [[ -z "${STATE_ID}" ]]; then
        STATE_ID="$1"
      else
        fail "unexpected arg: $1"
      fi
      shift
      ;;
  esac
done

[[ -n "${STATE_ID}" ]] || {
  usage
  exit 1
}

state_num="${STATE_ID%%-*}"
[[ "${state_num}" =~ ^[0-9]+$ ]] || fail "invalid state id format: ${STATE_ID}"
state_num_decimal=$((10#${state_num}))

[[ -d "${TARGET_ROOT}" ]] || fail "target root not found: ${TARGET_ROOT}"

STATE_METADATA="${TARGET_ROOT}/ci/state-metadata.json"
if [[ "${state_num_decimal}" -ge 2 ]]; then
  [[ -f "${STATE_METADATA}" ]] || fail "missing state metadata: ${STATE_METADATA}"
fi

run_core_gates() {
  echo "[step] smoke dependency version targets"
  smoke_args=(--generated --target-root "${TARGET_ROOT}" --components-root "${COMPONENTS_ROOT}")
  if [[ "${SKIP_BRANCH_CONSISTENCY}" == "1" ]]; then
    echo "[warn] skipping generated-branch dependency consistency in smoke (--skip-branch-consistency)"
  else
    smoke_args+=(--branch-consistency --states "${STATE_ID}" --skip-branch-target-checks)
    if [[ "${ALLOW_MISSING_BRANCHES}" == "1" ]]; then
      smoke_args+=(--allow-missing-branches)
    fi
  fi
  bash "${ROOT}/pipeline/smoke-dependency-version-targets.sh" "${smoke_args[@]}"

  echo "[step] validate generated state contracts"
  bash "${ROOT}/pipeline/validate-generated-state-contracts.sh" "${TARGET_ROOT}"

  if [[ "${state_num_decimal}" -ge 2 ]]; then
    if [[ "${SKIP_COMPILE_PREFLIGHT}" == "1" ]]; then
      echo "[warn] skipping generated compile preflight (--skip-compile-preflight)"
    else
      echo "[step] run generated compile preflight"
      bash "${ROOT}/pipeline/preflight-generated-ci.sh" "${TARGET_ROOT}"
    fi
  fi

  if [[ "${state_num_decimal}" -ge 2 ]]; then
    echo "[step] validate generated UI status checks"
    bash "${ROOT}/pipeline/validate-generated-ui-status-checks.sh" "${STATE_ID}" "${TARGET_ROOT}" "${COMPONENTS_ROOT}"
  fi

  echo "[step] validate generated state lineage policy matrix"
  bash "${ROOT}/pipeline/validate-generated-state-lineage-invariants.sh" --policy-only

}

read_state_arrays() {
  require_cmd jq
  NODE_MODULES=()
  while IFS= read -r module; do
    [[ -z "${module}" ]] && continue
    NODE_MODULES+=("${module}")
  done < <(jq -r '.modules.node[]?' "${STATE_METADATA}")

  GRADLE_MODULES=()
  while IFS= read -r module; do
    [[ -z "${module}" ]] && continue
    GRADLE_MODULES+=("${module}")
  done < <(jq -r '.modules.gradle[]?' "${STATE_METADATA}")

  DOTNET_MODULES=()
  while IFS= read -r module; do
    [[ -z "${module}" ]] && continue
    DOTNET_MODULES+=("${module}")
  done < <(jq -r '.modules.dotnet[]?' "${STATE_METADATA}")

  DOCKER_MODULES=()
  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    DOCKER_MODULES+=("${entry}")
  done < <(jq -r '.modules.docker[]? | [.directory,.dockerfile,.imageName] | @tsv' "${STATE_METADATA}")
}

install_license_validator_if_needed() {
  if command -v node-license-validator >/dev/null 2>&1; then
    return 0
  fi
  echo "[step] install node-license-validator"
  npm install -g node-license-validator
}

run_license_scan() {
  if [[ "${SKIP_LICENSE_SCAN}" == "1" ]]; then
    echo "[warn] skipping Node license scan (--skip-license-scan)"
    return 0
  fi
  if ((${#NODE_MODULES[@]} == 0)); then
    echo "[info] no Node modules detected for license scan"
    return 0
  fi

  require_cmd npm
  install_license_validator_if_needed

  local module
  for module in "${NODE_MODULES[@]}"; do
    [[ -d "${TARGET_ROOT}/${module}" ]] || fail "missing Node module dir: ${TARGET_ROOT}/${module}"
    echo "[step] license scan: ${module}"
    (
      cd "${TARGET_ROOT}/${module}"
      npm install --omit=dev
      node-license-validator . --allow-licenses Apache-2.0 MIT BSD-2-Clause BSD BSD-3-Clause Unlicense ISC
    )
  done
}

run_container_build_preflight() {
  if [[ "${SKIP_CONTAINER_BUILD}" == "1" ]]; then
    echo "[warn] skipping Docker image build preflight (--skip-container-build)"
    return 0
  fi
  if ((${#DOCKER_MODULES[@]} == 0)); then
    echo "[info] no container build targets detected"
    return 0
  fi

  require_cmd docker

  local entry directory dockerfile image_name context_abs dockerfile_abs tag
  for entry in "${DOCKER_MODULES[@]}"; do
    IFS=$'\t' read -r directory dockerfile image_name <<<"${entry}"
    context_abs="${TARGET_ROOT}/${directory}"
    dockerfile_abs="${context_abs}/${dockerfile}"
    [[ -d "${context_abs}" ]] || fail "missing docker build context: ${context_abs}"
    [[ -f "${dockerfile_abs}" ]] || fail "missing dockerfile: ${dockerfile_abs}"
    tag="traderx-prepublish/${image_name}:local"

    echo "[step] docker build: ${image_name}"
    docker build -f "${dockerfile_abs}" -t "${tag}" "${context_abs}"
  done
}

run_dependency_check_local() {
  local project="$1"
  local scan_path="$2"
  local suppression="$3"
  local extra_args="$4"

  local report_dir="${TARGET_ROOT}/ci/local-security-reports/${project}"
  mkdir -p "${report_dir}"

  local update_args=()
  if [[ "${DEPENDENCY_CHECK_NO_UPDATE}" == "1" ]]; then
    update_args+=(--noupdate)
  fi

  if command -v dependency-check.sh >/dev/null 2>&1; then
    (
      cd "${TARGET_ROOT}"
      dependency-check.sh \
        --project "${project}" \
        --scan "${scan_path}" \
        --format HTML \
        --out "${report_dir}" \
        --suppression "${suppression}" \
        --failOnCVSS "${CVSS_THRESHOLD}" \
        --enableRetired \
        "${update_args[@]}" \
        ${extra_args}
    )
    return 0
  fi

  require_cmd docker
  mkdir -p "${DEPENDENCY_CHECK_DATA_DIR}"

  local rel_scan="${scan_path#${TARGET_ROOT}/}"
  local rel_suppression="${suppression#${TARGET_ROOT}/}"

  local docker_args=(
    run --rm
    -v "${TARGET_ROOT}:/src"
    -v "${DEPENDENCY_CHECK_DATA_DIR}:/usr/share/dependency-check/data"
    -v "${report_dir}:/report"
  )
  if [[ -n "${NVD_API_KEY:-}" ]]; then
    docker_args+=( -e "NVD_API_KEY=${NVD_API_KEY}" )
  fi

  docker "${docker_args[@]}" "${DEPENDENCY_CHECK_IMAGE}" \
    --project "${project}" \
    --scan "/src/${rel_scan}" \
    --format HTML \
    --out /report \
    --suppression "/src/${rel_suppression}" \
    --failOnCVSS "${CVSS_THRESHOLD}" \
    --enableRetired \
    "${update_args[@]}" \
    ${extra_args}
}

run_cve_scan() {
  if [[ "${SKIP_CVE_SCAN}" == "1" ]]; then
    echo "[warn] skipping CVE dependency scan (--skip-cve-scan)"
    return 0
  fi
  if [[ "${state_num}" -lt 2 ]]; then
    echo "[info] CVE dependency scan not required for pre-CI states"
    return 0
  fi

  local node_suppression="${TARGET_ROOT}/.github/node-cve-ignore-list.xml"
  local gradle_suppression="${TARGET_ROOT}/.github/gradle-cve-ignore-list.xml"
  local dotnet_suppression="${TARGET_ROOT}/.github/dotnet-cve-ignore-list.xml"

  [[ -f "${node_suppression}" ]] || fail "missing node CVE suppression file: ${node_suppression}"
  [[ -f "${gradle_suppression}" ]] || fail "missing gradle CVE suppression file: ${gradle_suppression}"
  [[ -f "${dotnet_suppression}" ]] || fail "missing dotnet CVE suppression file: ${dotnet_suppression}"

  local module
  if ((${#NODE_MODULES[@]} > 0)); then
    for module in "${NODE_MODULES[@]}"; do
      echo "[step] cve scan (node): ${module}"
      run_dependency_check_local "${module}-node" "${TARGET_ROOT}/${module}" "${node_suppression}" "--nodeAuditSkipDevDependencies --nodePackageSkipDevDependencies"
    done
  fi

  if ((${#DOTNET_MODULES[@]} > 0)); then
    for module in "${DOTNET_MODULES[@]}"; do
      echo "[step] cve scan (.NET): ${module}"
      run_dependency_check_local "${module}-dotnet" "${TARGET_ROOT}/${module}" "${dotnet_suppression}" ""
    done
  fi

  if ((${#GRADLE_MODULES[@]} > 0)); then
    for module in "${GRADLE_MODULES[@]}"; do
      echo "[step] cve scan (gradle): ${module}"
      run_dependency_check_local "${module}-gradle" "${TARGET_ROOT}/${module}" "${gradle_suppression}" "--disableCentral"
    done
  fi
}

run_core_gates

if [[ "${state_num_decimal}" -ge 2 ]]; then
  read_state_arrays
  run_license_scan
  run_container_build_preflight
  run_cve_scan
fi

echo "[ok] prepublish generated-state gate passed for ${STATE_ID}"
