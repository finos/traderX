#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="${1:-}"
TARGET_ROOT="${ROOT}/generated/code/target-generated"

if [[ -z "${STATE_ID}" ]]; then
  echo "usage: bash pipeline/generate-state.sh <state-id>"
  echo "example: bash pipeline/generate-state.sh 002-edge-proxy-uncontainerized"
  exit 1
fi

clean_target_root() {
  local attempts=6
  local delay=1
  local i

  for ((i=1; i<=attempts; i++)); do
    rm -rf "${TARGET_ROOT}" && break || true
    if (( i == attempts )); then
      echo "[fail] unable to clean target root after ${attempts} attempts: ${TARGET_ROOT}"
      echo "[hint] stop active state runtimes, then retry."
      exit 1
    fi
    echo "[warn] target cleanup retry ${i}/${attempts} for ${TARGET_ROOT}"
    sleep "${delay}"
  done

  mkdir -p "${TARGET_ROOT}"
}

# Always regenerate from a clean target so each state output is deterministic
# and does not carry unrelated artifacts from prior state runs.
clean_target_root

case "${STATE_ID}" in
  001-baseline-uncontainerized-parity)
    bash "${ROOT}/pipeline/generate-from-spec.sh"
    bash "${ROOT}/pipeline/generate-state-architecture-doc.sh" "${STATE_ID}"
    cat <<'EOF'
[summary] state=001-baseline-uncontainerized-parity
[summary] impacted-components=database,reference-data,trade-feed,people-service,account-service,position-service,trade-processor,trade-service,web-front-end-angular
[summary] runtime-entrypoint=./scripts/start-base-uncontainerized-generated.sh
EOF
    ;;
  002-edge-proxy-uncontainerized)
    bash "${ROOT}/pipeline/generate-state-002-edge-proxy-uncontainerized.sh"
    ;;
  003-containerized-compose-runtime)
    bash "${ROOT}/pipeline/generate-state-003-containerized-compose-runtime.sh"
    ;;
  *)
    HOOK="${ROOT}/pipeline/generate-state-${STATE_ID}.sh"
    if [[ -x "${HOOK}" ]]; then
      bash "${HOOK}"
    else
      echo "[fail] unsupported state-id: ${STATE_ID}"
      echo "[hint] add a state hook at ${HOOK} or implement explicit case logic."
      exit 1
    fi
    ;;
esac

bash "${ROOT}/pipeline/generate-state-docs-from-catalog.sh"
