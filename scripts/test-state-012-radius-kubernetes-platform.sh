#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"
INGRESS_URL="${1:-http://localhost:8080}"
NAMESPACE="${2:-traderx}"
K8S_PROVIDER="${3:-${K8S_PROVIDER:-kind}}"
CLUSTER_OR_PROFILE="${4:-${MINIKUBE_PROFILE:-traderx-state-009}}"
STATE_DIR="${GENERATED_ROOT}/code/target-generated/radius-kubernetes-platform"
RADIUS_DIR="${STATE_DIR}/radius"
UPSTREAM_BUILD_PLAN="${STATE_DIR}/upstream-build-plan.json"
UPSTREAM_SPEC="${GENERATED_ROOT}/code/target-generated/kubernetes-runtime/spec-source/kubernetes-runtime.spec.json"

echo "[check] state 009 baseline compatibility for state 012"
"${REPO_ROOT}/scripts/test-state-009-kubernetes-runtime.sh" "${INGRESS_URL}" "${NAMESPACE}" "${K8S_PROVIDER}" "${CLUSTER_OR_PROFILE}"

echo "[check] state 012 radius artifact pack exists"
for required in \
  "${STATE_DIR}/README.md" \
  "${UPSTREAM_BUILD_PLAN}" \
  "${RADIUS_DIR}/app.bicep" \
  "${RADIUS_DIR}/bicepconfig.json" \
  "${RADIUS_DIR}/.rad/rad.yaml"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing expected state 012 artifact: ${required}"
    exit 1
  }
done

echo "[check] radius app model has expected declarations"
grep -q '^extension radius' "${RADIUS_DIR}/app.bicep" || {
  echo "[error] app.bicep is missing 'extension radius'"
  exit 1
}
while IFS= read -r resource_name; do
  grep -q "name: '${resource_name}'" "${RADIUS_DIR}/app.bicep" || {
    echo "[error] app.bicep is missing resource declaration for ${resource_name}"
    exit 1
  }
done < <(jq -r '.components[].name, .runtime.edge.serviceName' "${UPSTREAM_SPEC}")

if command -v rad >/dev/null 2>&1; then
  echo "[check] radius CLI available"
  rad version | head -n 1
else
  echo "[info] radius CLI not installed; skipping optional rad command checks"
fi

echo "[done] state 012 radius-kubernetes platform smoke tests passed"
