#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTUAL="${ROOT}/generated/code/target-generated/corp-overlays/corp-001-managed-postgres-runtime/db.env"
EXPECTED="${ROOT}/examples/expected/corp-001-managed-postgres.env"

if [[ ! -f "${ACTUAL}" ]]; then
  echo "[fail] missing generated overlay output: ${ACTUAL}"
  echo "[hint] run ./scripts/demo-generate-corp-overlay.sh first"
  exit 1
fi

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  [[ "${line}" =~ ^# ]] && continue
  if ! grep -Fq "${line}" "${ACTUAL}"; then
    echo "[fail] expected line missing from actual output: ${line}"
    exit 1
  fi
done < "${EXPECTED}"

echo "[ok] corporate overlay output matches expected policy markers"
