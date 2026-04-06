#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
usage: bash pipeline/refresh-state-docs.sh [--check]

Refreshes all docs derived from catalog/state-catalog.json:
  - catalog/learning-paths.yaml
  - catalog/learning-paths.md
  - docs/spec-kit/state-docs.md
  - docs/learning-paths/index.md
  - docs/learning/index.md
  - docs/learning/state-*.md

Options:
  --check   verify generated docs are up to date without writing files
EOF
}

CHECK_MODE=0
while (($# > 0)); do
  case "$1" in
    --check)
      CHECK_MODE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[fail] unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

if (( CHECK_MODE == 1 )); then
  bash "${ROOT}/pipeline/generate-learning-paths-catalog.sh" --check
  bash "${ROOT}/pipeline/generate-state-docs-from-catalog.sh" --check
  echo "[ok] state catalog docs are up to date"
  exit 0
fi

bash "${ROOT}/pipeline/generate-learning-paths-catalog.sh"
bash "${ROOT}/pipeline/generate-state-docs-from-catalog.sh"
echo "[ok] refreshed state catalog docs"
