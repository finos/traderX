#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if (( ${TRADERX_GENERATION_DEPTH:-0} == 0 )); then
  exec bash "${ROOT}/pipeline/generate-state.sh" 017-portfolio-lookthrough
fi
bash "${ROOT}/pipeline/generate-state.sh" 009-order-management-matcher
python3 "${ROOT}/pipeline/render-portfolio-lookthrough.py" 017-portfolio-lookthrough
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" 017-portfolio-lookthrough
