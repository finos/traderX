#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_ROOT="${ROOT}/upstream/traderX"
TARGET_BRANCH="${1:-feature/agentic-renovation}"

if [[ ! -d "${UPSTREAM_ROOT}/.git" ]]; then
  echo "[fail] upstream submodule not found at ${UPSTREAM_ROOT}"
  echo "[hint] run: git submodule update --init --recursive"
  exit 1
fi

git -C "${UPSTREAM_ROOT}" fetch origin
git -C "${UPSTREAM_ROOT}" checkout "${TARGET_BRANCH}"
git -C "${UPSTREAM_ROOT}" pull --ff-only origin "${TARGET_BRANCH}"

echo "[ok] upstream submodule moved to ${TARGET_BRANCH}"
echo "[next] commit the submodule pointer in your corporate overlay repository"
