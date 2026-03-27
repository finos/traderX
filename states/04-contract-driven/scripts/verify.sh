#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

[[ -d "${ROOT}/specs/contracts" ]] || { echo "missing specs/contracts"; exit 1; }
[[ -f "${ROOT}/specs/contracts/trade-order-api.md" ]] || { echo "missing trade-order contract"; exit 1; }
[[ -d "${ROOT}/states/04-contract-driven/contract-tests" ]] || { echo "missing contract-tests"; exit 1; }
[[ -f "${ROOT}/states/04-contract-driven/contract-tests/README.md" ]] || { echo "missing contract-tests README"; exit 1; }

echo "[verify] 04-contract-driven checks passed"
