#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="${TRADERX_SECURITY_RUNTIME:-/private/tmp/traderx-security-runtime}"
mkdir -p "${RUNTIME}/snapshot" "${RUNTIME}/generated/code" "${RUNTIME}/evidence"
SNAPSHOT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["generated_commit"])' \
  "${ROOT}/specs/012-platform-convergence-c3/security-lab/baseline.lock.json")"
git -C "${ROOT}" archive "${SNAPSHOT}" | tar -x -C "${RUNTIME}/snapshot"
if [[ ! -e "${RUNTIME}/generated/code/target-generated" ]]; then
  ln -s "${RUNTIME}/snapshot" "${RUNTIME}/generated/code/target-generated"
fi
[[ "$(readlink "${RUNTIME}/generated/code/target-generated")" == "${RUNTIME}/snapshot" ]] || {
  echo '[fail] unexpected generated snapshot path' >&2
  exit 1
}
export KUBECONFIG="${RUNTIME}/kubeconfig"
if kubectl -n traderx-security-infra get daemonset/promtail >/dev/null 2>&1; then
  export TRADERX_LOG_COLLECTOR_NAMESPACE=traderx-security-infra
fi
export TRADERX_GENERATED_ROOT="${RUNTIME}/generated"
export TRADERX_LOCAL_RUNTIME_SCRIPT=1
export TRADERX_USE_PUBLISHED_IMAGES=1
bash "${ROOT}/scripts/test-state-012-platform-convergence-c3.sh" \
  http://127.0.0.1:18080 traderx-security-lab kind traderx-security-lab \
  | tee "${RUNTIME}/evidence/c3-smoke.log"
