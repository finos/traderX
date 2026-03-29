#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/catalog/state-catalog.json"

if [[ ! -f "${CATALOG}" ]]; then
  echo "[fail] missing state catalog: ${CATALOG}"
  exit 1
fi

while IFS= read -r state_id; do
  [[ -n "${state_id}" ]] || continue
  bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${state_id}"
done < <(jq -r '.states[].id' "${CATALOG}")

echo "[done] generated architecture docs for all catalog states"
