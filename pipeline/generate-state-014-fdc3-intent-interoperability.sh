#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="014-fdc3-intent-interoperability"
PARENT_STATE_ID="012-platform-convergence-c3"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/render-state-014-fdc3-intent-interoperability.sh"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOT'
[summary] state=014-fdc3-intent-interoperability
[summary] parent-state=012-platform-convergence-c3
[summary] impacted-assets=fdc3-interop-spec-pack,sail-sidecar-compose,traderx-appd-overlay
[summary] generated-path=generated/code/target-generated/fdc3-intent-interoperability
[summary] runtime-entrypoint=./scripts/start-state-014-fdc3-intent-interoperability-generated.sh
EOT
