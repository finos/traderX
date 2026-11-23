#!/usr/bin/env bash
# Offline artifact check only: does not start containers or apply Kubernetes resources.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${TRADERX_SECURITY_PYTHON:-python3}"
OUTPUT="$(mktemp -d "${TMPDIR:-/tmp}/traderx-019-checkpoint.XXXXXX")"
trap 'rm -rf "${OUTPUT}"' EXIT
"${PYTHON}" "${ROOT}/scripts/security-lab/checkpoint.py" generate --output "${OUTPUT}/first"
"${PYTHON}" "${ROOT}/scripts/security-lab/checkpoint.py" generate --output "${OUTPUT}/second"
diff -r "${OUTPUT}/first" "${OUTPUT}/second"
"${PYTHON}" "${ROOT}/scripts/security-lab/checkpoint.py" verify --output "${OUTPUT}/first"
echo '[ok] State 019 offline checkpoint repeats byte-for-byte; integrated runtime acceptance pending'
