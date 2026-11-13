#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if (( ${TRADERX_GENERATION_DEPTH:-0} == 0 )); then
  exec bash "${ROOT}/pipeline/generate-state.sh" 018-falkordb-lookthrough
fi
bash "${ROOT}/pipeline/generate-state.sh" 017-portfolio-lookthrough
python3 "${ROOT}/pipeline/render-portfolio-lookthrough.py" 018-falkordb-lookthrough
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" 018-falkordb-lookthrough
