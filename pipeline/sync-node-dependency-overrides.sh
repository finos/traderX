#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS_FILE="${TRADERX_DEPENDENCY_TARGETS_FILE:-${ROOT}/catalog/dependency-version-targets.json}"

fail() {
  echo "[fail] $*"
  exit 1
}

if [[ "$#" -lt 1 ]]; then
  echo "usage: bash pipeline/sync-node-dependency-overrides.sh <root> [root...]"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  fail "jq is required"
fi

[[ -f "${TARGETS_FILE}" ]] || fail "missing dependency targets file: ${TARGETS_FILE}"

override_targets="$(mktemp)"
trap 'rm -f "${override_targets}"' EXIT

jq -r '(.npm.overrides // {}) | to_entries[] | [.key, (.value | tostring)] | @tsv' "${TARGETS_FILE}" > "${override_targets}"

if [[ ! -s "${override_targets}" ]]; then
  echo "[ok] no npm override targets declared in ${TARGETS_FILE}"
  exit 0
fi

updated=0
unchanged=0
skipped=0

lock_contains_dependency() {
  local lock_file="$1"
  local dep="$2"

  jq -e --arg dep "${dep}" '
    (.packages["node_modules/" + $dep] // null) != null
    or (.dependencies[$dep] // null) != null
  ' "${lock_file}" >/dev/null
}

manifest_has_override() {
  local package_file="$1"
  local dep="$2"

  jq -e --arg dep "${dep}" '(.overrides[$dep] // null) != null' "${package_file}" >/dev/null
}

sync_package_manifest() {
  local package_file="$1"
  local module_dir
  local lock_file
  local updates
  local dep
  local target

  module_dir="$(dirname "${package_file}")"
  lock_file="${module_dir}/package-lock.json"
  updates="{}"

  if [[ ! -f "${lock_file}" ]]; then
    skipped=$((skipped + 1))
    return
  fi

  while IFS=$'\t' read -r dep target; do
    [[ -n "${dep}" && -n "${target}" ]] || continue
    if manifest_has_override "${package_file}" "${dep}" || lock_contains_dependency "${lock_file}" "${dep}"; then
      updates="$(jq -c --argjson updates "${updates}" --arg dep "${dep}" --arg target "${target}" -n '$updates + {($dep): $target}')"
    fi
  done < "${override_targets}"

  if [[ "${updates}" == "{}" ]]; then
    unchanged=$((unchanged + 1))
    return
  fi

  tmp_file="$(mktemp)"
  jq --indent 2 --argjson updates "${updates}" '.overrides = ((.overrides // {}) + $updates)' "${package_file}" > "${tmp_file}"

  if cmp -s "${package_file}" "${tmp_file}"; then
    rm -f "${tmp_file}"
    unchanged=$((unchanged + 1))
    return
  fi

  mv "${tmp_file}" "${package_file}"
  updated=$((updated + 1))
  echo "[info] synced npm overrides: ${module_dir}"
}

for scan_root in "$@"; do
  [[ -d "${scan_root}" ]] || continue
  while IFS= read -r package_file; do
    sync_package_manifest "${package_file}"
  done < <(
    find "${scan_root}" -type f -name package.json \
      ! -path '*/node_modules/*' \
      ! -path '*/dist/*' \
      ! -path '*/build/*' \
      ! -path '*/coverage/*' \
      ! -path '*/.angular/*' \
      ! -path '*/.vite/*' \
      -print | sort
  )
done

echo "[ok] node dependency override sync complete (updated=${updated}, unchanged=${unchanged}, skipped=${skipped})"
