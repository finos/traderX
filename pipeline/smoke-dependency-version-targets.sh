#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${ROOT}/generated}"
TARGET_ROOT="${GENERATED_ROOT}/code/target-generated"
COMPONENTS_ROOT="${GENERATED_ROOT}/code/components"
RUN_GENERATED=0
RUN_BRANCH_CONSISTENCY=0
STATE_FILTER=""
ALLOW_MISSING_BRANCHES=0

usage() {
  cat <<'USAGE'
usage: bash pipeline/smoke-dependency-version-targets.sh [--generated] [--target-root <dir>] [--components-root <dir>] [--branch-consistency] [--states <comma-separated-state-ids>] [--allow-missing-branches]

Runs quick dependency version target smoke checks before expensive generation,
prepublish, or merge validation.

Defaults to template/catalog checks only.
USAGE
}

fail() {
  echo "[fail] $*"
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --generated)
      RUN_GENERATED=1
      shift
      ;;
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
    --branch-consistency)
      RUN_BRANCH_CONSISTENCY=1
      shift
      ;;
    --states)
      STATE_FILTER="${2:-}"
      [[ -n "${STATE_FILTER}" ]] || fail "--states requires a value"
      shift 2
      ;;
    --allow-missing-branches)
      ALLOW_MISSING_BRANCHES=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown arg: $1"
      ;;
  esac
done

has_dependency_files() {
  local root="$1"
  [[ -d "${root}" ]] || return 1
  find "${root}" -type f \
    \( -name 'build.gradle' -o -name 'gradle-wrapper.properties' -o -name 'package.json' -o -name '*.csproj' \) \
    ! -path '*/node_modules/*' \
    -print -quit | grep -q .
}

echo "[step] smoke template dependency version targets"
bash "${ROOT}/pipeline/validate-template-version-consistency.sh"

if [[ "${RUN_GENERATED}" == "1" ]]; then
  dep_roots=()
  if has_dependency_files "${COMPONENTS_ROOT}"; then
    dep_roots+=("${COMPONENTS_ROOT}")
  fi
  if has_dependency_files "${TARGET_ROOT}"; then
    dep_roots+=("${TARGET_ROOT}")
  fi

  if ((${#dep_roots[@]} == 0)); then
    fail "no generated dependency-bearing files found under ${COMPONENTS_ROOT} or ${TARGET_ROOT}"
  fi

  echo "[step] smoke generated dependency version targets"
  bash "${ROOT}/pipeline/validate-generated-dependency-targets.sh" "${dep_roots[@]}"
fi

if [[ "${RUN_BRANCH_CONSISTENCY}" == "1" ]]; then
  args=()
  if [[ -n "${STATE_FILTER}" ]]; then
    args+=(--states "${STATE_FILTER}")
  fi
  if [[ "${ALLOW_MISSING_BRANCHES}" == "1" ]]; then
    args+=(--allow-missing-branches)
  fi

  echo "[step] smoke generated-branch dependency consistency"
  bash "${ROOT}/pipeline/validate-generated-branch-dependency-consistency.sh" "${args[@]}"
fi

echo "[ok] dependency version target smoke checks passed"
