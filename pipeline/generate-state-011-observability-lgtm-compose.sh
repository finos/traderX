#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="011-observability-lgtm-compose"
PARENT_STATE_ID="003-containerized-compose-runtime"

echo "[info] generating parent state ${PARENT_STATE_ID} for ${STATE_ID}"
bash "${ROOT}/pipeline/generate-state.sh" "${PARENT_STATE_ID}"
bash "${ROOT}/pipeline/apply-state-patchset.sh" "${STATE_ID}"
bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"

cat <<'EOT'
[summary] state=011-observability-lgtm-compose
[summary] parent-state=003-containerized-compose-runtime
[summary] impacted-assets=compose-runtime,lgtm-stack,grafana-dashboards,prometheus-probes,otel-collector
[summary] generated-path=generated/code/target-generated/observability-lgtm-compose
[summary] runtime-entrypoint=./scripts/start-state-011-observability-lgtm-compose-generated.sh
EOT
