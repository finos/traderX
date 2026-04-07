#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "usage: ./scripts/bootstrap-overlay-repo.sh <target-dir> [upstream-branch]"
  exit 1
fi

TARGET_DIR="$1"
UPSTREAM_BRANCH="${2:-feature/agentic-renovation}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

mkdir -p "${TARGET_DIR}"
rsync -a "${TEMPLATE_ROOT}/" "${TARGET_DIR}/"

if [[ ! -d "${TARGET_DIR}/.git" ]]; then
  git -C "${TARGET_DIR}" init
fi

if [[ ! -d "${TARGET_DIR}/upstream/traderX" ]]; then
  git -C "${TARGET_DIR}" submodule add -b "${UPSTREAM_BRANCH}" https://github.com/finos/traderX.git upstream/traderX
fi

git -C "${TARGET_DIR}" submodule update --init --recursive

echo "[ok] corporate overlay repo bootstrapped at ${TARGET_DIR}"
echo "[next] run ${TARGET_DIR}/scripts/render-internal-learning-graph.sh"
