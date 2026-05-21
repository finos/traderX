#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash pipeline/publish-state-branch.sh <state-id> <base-branch> <target-branch> <snapshot-dir> [--push]
#
# Branch invariant:
# - Exactly one content commit per generated-state branch.
# - Always reset target branch to base before creating new snapshot commit.
# - Force-push replaces prior snapshot commit.

STATE_ID="${1:-}"
BASE_BRANCH="${2:-}"
TARGET_BRANCH="${3:-}"
SNAPSHOT_DIR="${4:-}"
PUSH_FLAG="${5:-}"

if [[ -z "${STATE_ID}" || -z "${BASE_BRANCH}" || -z "${TARGET_BRANCH}" || -z "${SNAPSHOT_DIR}" ]]; then
  echo "usage: $0 <state-id> <base-branch> <target-branch> <snapshot-dir> [--push]"
  exit 1
fi

if [[ ! -d "${SNAPSHOT_DIR}" ]]; then
  echo "[fail] snapshot directory not found: ${SNAPSHOT_DIR}"
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# Start from base branch, then hard reset target branch to that base tip.
git fetch --all --prune
git checkout "${BASE_BRANCH}"
git pull --ff-only || true
git checkout -B "${TARGET_BRANCH}"

# Replace repository contents with snapshot (except .git metadata).
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -R "${SNAPSHOT_DIR}"/. .

# Create one snapshot commit for this state.
git add -A
git commit -m "chore: publish generated snapshot ${STATE_ID}"

if [[ "${PUSH_FLAG}" == "--push" ]]; then
  git push --force origin "${TARGET_BRANCH}"
  echo "[ok] pushed ${TARGET_BRANCH} with one-commit snapshot model"
else
  echo "[ok] prepared ${TARGET_BRANCH}; run with --push to publish"
fi
