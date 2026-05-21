#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="003-agentic-harness-foundation"
PARENT_STATE_ID="002-edge-proxy-uncontainerized"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOT'
[summary] state=003-agentic-harness-foundation
[summary] inherited-runtime=002-edge-proxy-uncontainerized
[summary] added-generated-metadata=AGENTS.md,ARCHITECTURE.md,CONTRIBUTING.md
[summary] runtime-entrypoint=./scripts/start-state-003-agentic-harness-foundation-generated.sh
EOT
