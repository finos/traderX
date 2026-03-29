#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

for generator in \
  generate-account-service-specfirst.sh \
  generate-trade-service-specfirst.sh \
  generate-position-service-specfirst.sh \
  generate-reference-data-specfirst.sh \
  generate-people-service-specfirst.sh; do
  [[ -f "${ROOT}/pipeline/${generator}" ]] || { echo "missing ${generator}"; exit 1; }
done

echo "[verify] 01-basic-microservices checks passed"
