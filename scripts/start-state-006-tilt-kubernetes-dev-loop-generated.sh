#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="006-tilt-kubernetes-dev-loop"
STATE_DIR="${REPO_ROOT}/generated/code/target-generated/tilt-kubernetes-dev-loop"
TILT_DIR="${STATE_DIR}/tilt"

DRY_RUN=0
SKIP_BUILD=0
RECREATE_CLUSTER=0
RUN_TILT=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
MINIKUBE_PROFILE=""
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --recreate-cluster)
      RECREATE_CLUSTER=1
      ;;
    --run-tilt)
      RUN_TILT=1
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --minikube-profile)
      MINIKUBE_PROFILE="${2:-}"
      shift
      ;;
    --minikube-driver)
      MINIKUBE_DRIVER="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run --skip-build --recreate-cluster --run-tilt --provider <kind|minikube> --minikube-profile <name> --minikube-driver <name>"
      exit 1
      ;;
  esac
  shift
done

bash "${REPO_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"

for required in \
  "${STATE_DIR}/README.md" \
  "${TILT_DIR}/Tiltfile" \
  "${TILT_DIR}/tilt-settings.json" \
  "${TILT_DIR}/README.md"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing generated state 006 artifact: ${required}"
    exit 1
  }
done

start_args=(--provider "${K8S_PROVIDER}")
start_args+=(--skip-generate)
if (( DRY_RUN == 1 )); then
  start_args+=(--dry-run)
fi
if (( SKIP_BUILD == 1 )); then
  start_args+=(--skip-build)
fi
if (( RECREATE_CLUSTER == 1 )); then
  start_args+=(--recreate-cluster)
fi
if [[ -n "${MINIKUBE_PROFILE}" ]]; then
  start_args+=(--minikube-profile "${MINIKUBE_PROFILE}")
fi
if [[ -n "${MINIKUBE_DRIVER}" ]]; then
  start_args+=(--minikube-driver "${MINIKUBE_DRIVER}")
fi

"${REPO_ROOT}/scripts/start-state-004-kubernetes-generated.sh" "${start_args[@]}"

if (( DRY_RUN == 1 )); then
  echo "[dry-run] tilt assets validated at ${TILT_DIR}"
  if (( RUN_TILT == 1 )); then
    echo "[dry-run] (cd ${TILT_DIR} && tilt up)"
  fi
  echo "[done] dry run complete for state 006"
  exit 0
fi

echo "[info] state 006 tilt assets ready at ${TILT_DIR}"
if command -v tilt >/dev/null 2>&1; then
  echo "[info] tilt CLI detected: $(tilt version | head -n 1)"
  if (( RUN_TILT == 1 )); then
    echo "[start] launching Tilt from ${TILT_DIR}"
    cd "${TILT_DIR}"
    exec tilt up
  fi
  echo "[hint] run: (cd ${TILT_DIR} && tilt up)"
else
  echo "[info] tilt CLI not found; install Tilt to run local dev loop"
fi

echo "[done] state 006 tilt-kubernetes dev loop ready (runtime inherited from state 004)"
