#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${ROOT}/TraderSpec/codebase/target-generated"
APPS="${TARGET}/apps"

mkdir -p "${APPS}"

modules=(
  account-service
  trade-service
  position-service
  trade-processor
  reference-data
  people-service
  trade-feed
  database
  ingress
  web-front-end/angular
)

for module in "${modules[@]}"; do
  src="${ROOT}/${module}"
  dst="${APPS}/${module}"
  [[ -d "${src}" ]] || { echo "[skip] missing ${module}"; continue; }
  if [[ "${module}" == "web-front-end/angular" ]]; then
    rm -rf "${APPS}/web-front-end"
  fi
  rm -rf "${dst}"
  mkdir -p "$(dirname "${dst}")"
  cp -R "${src}" "${dst}"
  echo "[copy] ${module}"
done

cp "${ROOT}/docker-compose.yml" "${TARGET}/docker-compose.yml"
cat <<'EOF' > "${TARGET}/README.current-parity.md"
# Current Parity Snapshot

This is a parity reference snapshot for the current TraderX runtime behavior.

Scope:

- Includes backend services and Angular frontend path.
- React frontend is intentionally excluded from this active TraderSpec baseline.

Use this snapshot for behavior comparison only.
EOF

echo "[done] baseline parity snapshot copied into ${TARGET}"
