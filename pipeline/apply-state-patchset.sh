#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="${1:-}"
TARGET_ROOT="${2:-${ROOT}/generated/code/target-generated}"
PATCH_DIR="${ROOT}/specs/${STATE_ID}/generation/patches"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/apply-state-patchset.sh <state-id> [target-root]"
  exit 1
fi

if [[ ! -d "${TARGET_ROOT}" ]]; then
  echo "[fail] target root does not exist: ${TARGET_ROOT}"
  exit 1
fi

if [[ "${TARGET_ROOT}" != "${ROOT}"/* ]]; then
  echo "[fail] target root must be under repository root for git-apply directory routing"
  echo "[hint] target=${TARGET_ROOT}"
  echo "[hint] root=${ROOT}"
  exit 1
fi

if [[ ! -d "${PATCH_DIR}" ]]; then
  echo "[fail] missing patch directory: ${PATCH_DIR}"
  exit 1
fi

TARGET_REL="${TARGET_ROOT#${ROOT}/}"

patch_files=()
while IFS= read -r patch_file; do
  patch_files+=("${patch_file}")
done < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' | sort)

if [[ "${#patch_files[@]}" -eq 0 ]]; then
  echo "[fail] no patch files found in ${PATCH_DIR}"
  exit 1
fi

for patch_file in "${patch_files[@]}"; do
  git -C "${ROOT}" apply --check --whitespace=nowarn --directory="${TARGET_REL}" "${patch_file}"
done

for patch_file in "${patch_files[@]}"; do
  git -C "${ROOT}" apply --whitespace=nowarn --directory="${TARGET_REL}" "${patch_file}"
  echo "[apply] ${patch_file}"
done

echo "[done] applied ${#patch_files[@]} patch(es) for ${STATE_ID} into ${TARGET_ROOT}"
