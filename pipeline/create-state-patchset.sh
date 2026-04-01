#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="${1:-}"
PARENT_STATE_ID="${2:-}"
TARGET_PATH_ARG="${3:-generated/code/target-generated}"
TARGET_PATH="${ROOT}/${TARGET_PATH_ARG}"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/create-state-patchset.sh <state-id> [parent-state-id] [target-path]"
  echo "example: bash pipeline/create-state-patchset.sh 007-messaging-nats-replacement"
  echo "example: bash pipeline/create-state-patchset.sh 002-edge-proxy-uncontainerized 001-baseline-uncontainerized-parity generated/code/components"
  exit 1
fi

if [[ -z "${PARENT_STATE_ID}" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "[fail] jq is required when parent-state-id is omitted"
    exit 1
  fi

  PARENT_STATE_ID="$(
    jq -r --arg state "${STATE_ID}" '.states[] | select(.id == $state) | .previous[0] // empty' \
      "${ROOT}/catalog/state-catalog.json"
  )"
fi

if [[ -z "${PARENT_STATE_ID}" ]]; then
  echo "[fail] unable to resolve parent state for ${STATE_ID}"
  exit 1
fi

PATCH_DIR="${ROOT}/specs/${STATE_ID}/generation/patches"
PATCH_FILE="${PATCH_DIR}/0001-state-overlay.patch"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PARENT_SNAPSHOT="${TMP_DIR}/parent"
CHILD_SNAPSHOT="${TMP_DIR}/child"
DIFF_REPO="${TMP_DIR}/diff-repo"
RSYNC_EXCLUDES=(
  "--exclude=.git"
  "--exclude=.DS_Store"
  "--exclude=node_modules"
  "--exclude=node_modules/**"
  "--exclude=.angular"
  "--exclude=*.log"
)

echo "[info] generating parent state ${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
if [[ ! -d "${TARGET_PATH}" ]]; then
  echo "[fail] target path does not exist after parent generation: ${TARGET_PATH}"
  exit 1
fi
mkdir -p "${PARENT_SNAPSHOT}"
rsync -a --delete "${RSYNC_EXCLUDES[@]}" "${TARGET_PATH}/" "${PARENT_SNAPSHOT}/"

echo "[info] generating child state ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
if [[ ! -d "${TARGET_PATH}" ]]; then
  echo "[fail] target path does not exist after child generation: ${TARGET_PATH}"
  exit 1
fi
mkdir -p "${CHILD_SNAPSHOT}"
rsync -a --delete "${RSYNC_EXCLUDES[@]}" "${TARGET_PATH}/" "${CHILD_SNAPSHOT}/"

rm -rf "${DIFF_REPO}"
mkdir -p "${DIFF_REPO}"
rsync -a --delete "${PARENT_SNAPSHOT}/" "${DIFF_REPO}/"

git -C "${DIFF_REPO}" init -q
git -C "${DIFF_REPO}" add -A
git -C "${DIFF_REPO}" commit --allow-empty -qm "parent-${PARENT_STATE_ID}"

rsync -a --delete --exclude='.git' "${CHILD_SNAPSHOT}/" "${DIFF_REPO}/"
git -C "${DIFF_REPO}" add -A

mkdir -p "${PATCH_DIR}"
if git -C "${DIFF_REPO}" diff --cached --quiet; then
  : > "${PATCH_FILE}"
  echo "[warn] no differences detected between ${PARENT_STATE_ID} and ${STATE_ID}"
else
  git -C "${DIFF_REPO}" diff --cached --binary > "${PATCH_FILE}"
fi

if [[ ! -s "${PATCH_FILE}" ]]; then
  echo "[fail] empty patch file produced: ${PATCH_FILE}"
  exit 1
fi

echo "[done] wrote patch set for ${STATE_ID}: ${PATCH_FILE}"
