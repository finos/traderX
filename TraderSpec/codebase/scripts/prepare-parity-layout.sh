#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${ROOT}/codebase/target-generated"
APPS="${TARGET}/apps"

required=(
  account-service
  trade-service
  position-service
  trade-processor
  reference-data
  people-service
  trade-feed
  database
  ingress
  web-front-end
)

[[ -d "${APPS}" ]] || {
  echo "[error] missing ${APPS}; run TraderSpec/pipeline/generate-baseline-from-current.sh first"
  exit 1
}

for module in "${required[@]}"; do
  src="${APPS}/${module}"
  dst="${TARGET}/${module}"
  [[ -e "${src}" ]] || { echo "[error] missing ${src}"; exit 1; }
  if [[ -L "${dst}" || -d "${dst}" ]]; then
    rm -rf "${dst}"
  fi
  ln -s "apps/${module}" "${dst}"
  echo "[link] ${dst} -> apps/${module}"
done

echo "[ok] parity compose layout prepared in ${TARGET}"
