#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INGRESS_URL="${1:-http://localhost:8080}"
NAMESPACE="${2:-traderx}"
K8S_PROVIDER="${3:-${K8S_PROVIDER:-kind}}"
CLUSTER_OR_PROFILE="${4:-${MINIKUBE_PROFILE:-traderx-state-004}}"
STATE_DIR="${REPO_ROOT}/generated/code/target-generated/radius-kubernetes-platform"
RADIUS_DIR="${STATE_DIR}/radius"

echo "[check] state 004 baseline compatibility for state 005"
"${REPO_ROOT}/scripts/test-state-004-kubernetes-runtime.sh" "${INGRESS_URL}" "${NAMESPACE}" "${K8S_PROVIDER}" "${CLUSTER_OR_PROFILE}"

echo "[check] state 005 radius artifact pack exists"
for required in \
  "${STATE_DIR}/README.md" \
  "${RADIUS_DIR}/app.bicep" \
  "${RADIUS_DIR}/bicepconfig.json" \
  "${RADIUS_DIR}/.rad/rad.yaml"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing expected state 005 artifact: ${required}"
    exit 1
  }
done

echo "[check] radius app model has expected declarations"
grep -q '^extension radius' "${RADIUS_DIR}/app.bicep" || {
  echo "[error] app.bicep is missing 'extension radius'"
  exit 1
}
for resource_name in \
  "database" \
  "reference-data" \
  "trade-feed" \
  "people-service" \
  "account-service" \
  "position-service" \
  "trade-processor" \
  "trade-service" \
  "web-front-end-angular" \
  "edge-proxy"; do
  grep -q "name: '${resource_name}'" "${RADIUS_DIR}/app.bicep" || {
    echo "[error] app.bicep is missing resource declaration for ${resource_name}"
    exit 1
  }
done

if command -v rad >/dev/null 2>&1; then
  echo "[check] radius CLI available"
  rad version | head -n 1
else
  echo "[info] radius CLI not installed; skipping optional rad command checks"
fi

echo "[done] state 005 radius-kubernetes platform smoke tests passed"
