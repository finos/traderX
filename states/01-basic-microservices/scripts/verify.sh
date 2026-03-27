#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

for dir in account-service trade-service position-service reference-data people-service; do
  [[ -d "${ROOT}/${dir}" ]] || { echo "missing ${dir}"; exit 1; }
done

echo "[verify] 01-basic-microservices checks passed"
