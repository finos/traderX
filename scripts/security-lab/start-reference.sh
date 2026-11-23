#!/usr/bin/env bash
# Start only the dedicated reference lab. Never switches the user's kubeconfig.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${ROOT}/specs/012-platform-convergence-c3/security-lab"
RUNTIME="${TRADERX_SECURITY_RUNTIME:-/private/tmp/traderx-security-runtime}"
PYTHON="${TRADERX_SECURITY_PYTHON:-/private/tmp/traderx-security-lab-venv/bin/python}"
HELM="${TRADERX_SECURITY_HELM:-helm}"
CLUSTER="traderx-security-lab"
mkdir -p "${RUNTIME}/evidence"
export KUBECONFIG="${RUNTIME}/kubeconfig"
"${PYTHON}" "${ROOT}/scripts/security-lab/prepare_runtime.py" --output-dir "${RUNTIME}"
if kind get clusters | rg -qx "${CLUSTER}"; then
  docker start "${CLUSTER}-control-plane" >/dev/null
  kind get kubeconfig --name "${CLUSTER}" > "${KUBECONFIG}"
else
  kind create cluster --name "${CLUSTER}" --config "${PROFILE}/system/kind.yaml" --kubeconfig "${KUBECONFIG}"
fi
[[ "$(kubectl --context "kind-${CLUSTER}" get nodes -o jsonpath='{.items[0].metadata.name}')" == "${CLUSTER}-control-plane" ]] || {
  echo '[fail] unexpected cluster identity' >&2
  exit 1
}
"${HELM}" repo add cilium https://helm.cilium.io >/dev/null
"${HELM}" upgrade --install cilium cilium/cilium --version 1.20.5 --namespace kube-system \
  --kubeconfig "${KUBECONFIG}" --set ipam.mode=kubernetes --set operator.replicas=1 \
  --set kubeProxyReplacement=false --wait --timeout 180s
# Explicit platforms are needed for AMD64 C3 images on this ARM64 host.
"${PYTHON}" - "${RUNTIME}/images.lock.json" "${CLUSTER}-control-plane" <<'PY'
import json, subprocess, sys
for item in json.load(open(sys.argv[1]))['images'].values():
    subprocess.run(['docker', 'exec', sys.argv[2], 'ctr', '-n', 'k8s.io', 'images', 'pull',
                    '--platform', item['platform'], item['image']], check=True, timeout=240)
PY
kubectl --context "kind-${CLUSTER}" apply -f "${RUNTIME}/reference.json"
echo "[ready-for-tests] reference C3 deployed at http://127.0.0.1:18080; verify service readiness with test-reference.sh"
