#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSV="${ROOT}/catalog/component-spec.csv"

source "${ROOT}/pipeline/speckit/lib.sh"

[[ -f "${CSV}" ]] || {
  echo "[fail] missing component catalog: ${CSV}"
  exit 1
}

speckit_assert_global_readiness

row=0
components=0

while IFS=, read -r component_id kind source_path target_path language framework build_tool default_port contract_file depends_on required_env notes; do
  row=$((row + 1))
  if ((row == 1)); then
    continue
  fi

  [[ -n "${component_id}" ]] || {
    echo "[fail] empty component_id on row ${row}"
    exit 1
  }

  speckit_assert_component_ready "${component_id}"
  components=$((components + 1))
done < "${CSV}"

echo "[ok] Spec Kit readiness validated (${components} catalog components)"
