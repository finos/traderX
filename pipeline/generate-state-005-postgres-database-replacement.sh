#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="005-postgres-database-replacement"
PARENT_STATE_ID="004-containerized-compose-runtime"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOF'
[summary] state=005-postgres-database-replacement
[summary] parent-state=004-containerized-compose-runtime
[summary] impacted-components=database,account-service,position-service,trade-processor
[summary] impacted-assets=postgres-container,postgres-init-schema,compose-runtime
[summary] generated-path=generated/code/target-generated/postgres-database-replacement
[summary] runtime-entrypoint=./scripts/start-state-005-postgres-database-replacement-generated.sh
EOF
