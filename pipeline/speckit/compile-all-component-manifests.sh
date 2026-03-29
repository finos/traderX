#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSV="${ROOT}/catalog/component-spec.csv"

row=0
while IFS=, read -r component_id _; do
  row=$((row + 1))
  if (( row == 1 )); then
    continue
  fi

  bash "${ROOT}/pipeline/speckit/compile-component-manifest.sh" "${component_id}"
done < "${CSV}"

echo "[ok] compiled manifests for all catalog components"
