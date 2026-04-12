#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="${1:-}"
LOCK_HASH_FIELD="traderxPackageJsonSha256"

if [[ -z "${TARGET_ROOT}" ]]; then
  echo "usage: bash pipeline/refresh-generated-node-lockfiles.sh <target-root>"
  exit 1
fi

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "[warn] npm not found; skipping node lockfile refresh under ${TARGET_ROOT}"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[fail] jq is required for node lockfile refresh under ${TARGET_ROOT}"
  exit 1
fi

if ! command -v shasum >/dev/null 2>&1; then
  echo "[fail] shasum is required for node lockfile refresh under ${TARGET_ROOT}"
  exit 1
fi

package_files=()
while IFS= read -r -d '' package_file; do
  package_files+=("${package_file}")
done < <(
  find "${TARGET_ROOT}" -type f -name package.json \
    -not -path '*/node_modules/*' \
    -not -path '*/dist/*' \
    -not -path '*/coverage/*' \
    -print0 | sort -z
)

if ((${#package_files[@]} == 0)); then
  echo "[info] no package.json files found under ${TARGET_ROOT}; skipping lock refresh"
  exit 0
fi

hash_package_manifest() {
  local package_file="$1"
  jq -S -c '.' "${package_file}" | shasum -a 256 | awk '{print $1}'
}

package_manifest_matches_lockfile() {
  local package_file="$1"
  local lock_file="$2"

  jq -n \
    --slurpfile pkg "${package_file}" \
    --slurpfile lock "${lock_file}" '
      ($pkg[0] // {}) as $p |
      ($lock[0] // {}) as $l |
      ($l.packages[""] // {}) as $r |
      (($p.name // "") == ($r.name // "")) and
      (($p.version // "") == ($r.version // "")) and
      (($p.dependencies // {}) == ($r.dependencies // {})) and
      (($p.devDependencies // {}) == ($r.devDependencies // {})) and
      (($p.optionalDependencies // {}) == ($r.optionalDependencies // {})) and
      (($p.peerDependencies // {}) == ($r.peerDependencies // {}))
    ' >/dev/null
}

annotate_lockfile_hash() {
  local lock_file="$1"
  local package_hash="$2"
  local tmp_file
  tmp_file="$(mktemp)"
  jq --arg hash "${package_hash}" --arg field "${LOCK_HASH_FIELD}" \
    '.[$field] = $hash' "${lock_file}" > "${tmp_file}"
  mv "${tmp_file}" "${lock_file}"
}

refresh_count=0
annotate_count=0
skip_count=0

for package_file in "${package_files[@]}"; do
  module_dir="$(dirname "${package_file}")"
  lock_file="${module_dir}/package-lock.json"
  package_hash="$(hash_package_manifest "${package_file}")"
  should_refresh=0
  should_annotate=0
  reason=""

  if [[ "${TRADERX_FORCE_LOCKFILE_REFRESH:-0}" == "1" ]]; then
    should_refresh=1
    reason="forced"
  elif [[ ! -f "${lock_file}" ]]; then
    should_refresh=1
    reason="missing lockfile"
  elif ! jq -e '.' "${lock_file}" >/dev/null 2>&1; then
    should_refresh=1
    reason="invalid lockfile JSON"
  else
    stored_hash="$(jq -r --arg field "${LOCK_HASH_FIELD}" '.[$field] // empty' "${lock_file}")"
    if [[ -n "${stored_hash}" ]]; then
      if [[ "${stored_hash}" != "${package_hash}" ]]; then
        should_refresh=1
        reason="package manifest hash changed"
      fi
    elif package_manifest_matches_lockfile "${package_file}" "${lock_file}"; then
      should_annotate=1
      reason="backfill manifest hash"
    else
      should_refresh=1
      reason="manifest/lockfile mismatch"
    fi
  fi

  if (( should_refresh == 0 && should_annotate == 0 )); then
    echo "[info] lockfile up-to-date: ${module_dir}"
    skip_count=$((skip_count + 1))
    continue
  fi

  if (( should_annotate == 1 )); then
    echo "[info] annotating package-lock.json (${reason}): ${module_dir}"
    annotate_lockfile_hash "${lock_file}" "${package_hash}"
    annotate_count=$((annotate_count + 1))
    continue
  fi

  echo "[info] refreshing package-lock.json (${reason}): ${module_dir}"
  (
    cd "${module_dir}"
    rm -f "${lock_file}"
    npm install --package-lock-only --ignore-scripts --no-audit --no-fund
  )
  annotate_lockfile_hash "${lock_file}" "${package_hash}"
  refresh_count=$((refresh_count + 1))
done

echo "[ok] node lockfile sync complete under ${TARGET_ROOT} (refreshed=${refresh_count}, annotated=${annotate_count}, unchanged=${skip_count})"
