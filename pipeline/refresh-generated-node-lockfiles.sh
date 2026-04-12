#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="${1:-}"

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

for package_file in "${package_files[@]}"; do
  module_dir="$(dirname "${package_file}")"
  echo "[info] refreshing package-lock.json: ${module_dir}"
  (
    cd "${module_dir}"
    rm -f package-lock.json
    npm install --package-lock-only --ignore-scripts --no-audit --no-fund
  )
done

echo "[ok] refreshed node lockfiles under ${TARGET_ROOT}"
