#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DELETE_CLUSTER=0
STOP_TILT=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --delete-cluster)
      DELETE_CLUSTER=1
      ;;
    --stop-tilt)
      STOP_TILT=1
      ;;
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
      echo "[hint] supported: --delete-cluster --stop-tilt --provider <kind|minikube> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

if (( STOP_TILT == 1 )); then
  pids="$(pgrep -f "tilt up" || true)"
  for pid in ${pids}; do
    if kill -0 "${pid}" >/dev/null 2>&1; then
      echo "[stop] tilt up process (pid ${pid})"
      kill "${pid}" >/dev/null 2>&1 || true
    fi
  done
fi

stop_args=(--provider "${K8S_PROVIDER}")
if (( DELETE_CLUSTER == 1 )); then
  stop_args+=(--delete-cluster)
fi
if [[ -n "${MINIKUBE_PROFILE}" ]]; then
  stop_args+=(--minikube-profile "${MINIKUBE_PROFILE}")
fi

"${REPO_ROOT}/scripts/stop-state-004-kubernetes-generated.sh" "${stop_args[@]}"
echo "[done] state 006 stop sequence complete"
