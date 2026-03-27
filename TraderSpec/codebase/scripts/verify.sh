#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

[[ -f "${ROOT}/codebase/current-behavior/README.md" ]] || { echo "missing current-behavior reference"; exit 1; }
[[ -f "${ROOT}/codebase/target-generated/README.md" ]] || { echo "missing target-generated README"; exit 1; }

echo "[ok] codebase scaffold verification passed"
