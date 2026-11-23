#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHON="${TRADERX_SECURITY_PYTHON:-python3}"
"${PYTHON}" "${ROOT}/scripts/security-lab/prepare_waf.py" --runtime-dir "$1"
"${PYTHON}" "${ROOT}/scripts/security-lab/verify_waf.py" --runtime-dir "$2"
