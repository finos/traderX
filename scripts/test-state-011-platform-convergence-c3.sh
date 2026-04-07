#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi
INGRESS_URL="${1:-http://localhost:8080}"
NAMESPACE="${2:-traderx}"
K8S_PROVIDER="${3:-${K8S_PROVIDER:-kind}}"
CLUSTER_OR_PROFILE="${4:-${MINIKUBE_PROFILE:-traderx-state-009}}"
STATE_DIR="${GENERATED_ROOT}/code/target-generated/tilt-kubernetes-dev-loop"
TILT_DIR="${STATE_DIR}/tilt"
UPSTREAM_BUILD_PLAN="${STATE_DIR}/upstream-build-plan.json"
TILTFILE="${TILT_DIR}/Tiltfile"

echo "[check] state 010 baseline compatibility for state 011"
"${REPO_ROOT}/scripts/test-state-010-tilt-kubernetes-dev-loop.sh" "${INGRESS_URL}" "${NAMESPACE}" "${K8S_PROVIDER}" "${CLUSTER_OR_PROFILE}"

echo "[check] state 011 convergence artifact pack exists"
for required in \
  "${STATE_DIR}/README.md" \
  "${UPSTREAM_BUILD_PLAN}" \
  "${TILTFILE}" \
  "${TILT_DIR}/tilt-settings.json" \
  "${TILT_DIR}/README.md"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing expected state 011 artifact: ${required}"
    exit 1
  }
done

echo "[check] tiltfile structure"
grep -q "allow_k8s_contexts" "${TILTFILE}" || {
  echo "[error] Tiltfile missing allow_k8s_contexts"
  exit 1
}
grep -q "k8s_yaml" "${TILTFILE}" || {
  echo "[error] Tiltfile missing k8s_yaml declaration"
  exit 1
}
grep -q "k8s_resource('edge-proxy'" "${TILTFILE}" || {
  echo "[error] Tiltfile missing edge-proxy resource declaration"
  exit 1
}

while IFS= read -r item; do
  image="$(jq -r '.image' <<<"${item}")"
  grep -q "${image}" "${TILTFILE}" || {
    echo "[error] Tiltfile missing docker_build mapping for image ${image}"
    exit 1
  }
done < <(jq -c '.images[]' "${UPSTREAM_BUILD_PLAN}")

if grep -q "radius" "${TILTFILE}"; then
  echo "[error] Tiltfile should not include radius artifacts in state 011"
  exit 1
fi

if command -v tilt >/dev/null 2>&1; then
  echo "[check] tilt CLI available"
  tilt version | head -n 1
else
  echo "[info] tilt CLI not installed; skipping optional tilt command checks"
fi

echo "[done] state 011 platform convergence smoke tests passed"
