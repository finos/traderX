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
STATE_DIR="${GENERATED_ROOT}/code/target-generated/tilt-kubernetes-dev-loop"
TILT_DIR="${STATE_DIR}/tilt"

K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --provider <kind|minikube> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

status_args=(--provider "${K8S_PROVIDER}")
if [[ -n "${MINIKUBE_PROFILE}" ]]; then
  status_args+=(--minikube-profile "${MINIKUBE_PROFILE}")
fi

"${REPO_ROOT}/scripts/status-state-009-kubernetes-runtime-generated.sh" "${status_args[@]}"

echo
echo "[status] tilt artifacts"
for target in \
  "${STATE_DIR}/README.md" \
  "${TILT_DIR}/Tiltfile" \
  "${TILT_DIR}/tilt-settings.json" \
  "${TILT_DIR}/README.md"; do
  if [[ -f "${target}" ]]; then
    echo "[ok] ${target}"
  else
    echo "[missing] ${target}"
  fi
done

tilt_running="no"
if pgrep -af "tilt up" >/dev/null 2>&1; then
  tilt_running="yes"
fi
echo "[info] tilt-up-running: ${tilt_running}"

if command -v tilt >/dev/null 2>&1; then
  echo "[info] tilt CLI: $(tilt version | head -n 1)"
else
  echo "[info] tilt CLI not found on PATH"
fi
