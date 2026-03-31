#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="005-radius-kubernetes-platform"
STATE_DIR="${REPO_ROOT}/generated/code/target-generated/radius-kubernetes-platform"
RADIUS_DIR="${STATE_DIR}/radius"

DRY_RUN=0
SKIP_BUILD=0
RECREATE_CLUSTER=0
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
      echo "[hint] supported: --dry-run --skip-build --recreate-cluster --provider <kind|minikube> --minikube-profile <name> --minikube-driver <name>"
      exit 1
      ;;
  esac
  shift
done

bash "${REPO_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"

for required in \
  "${STATE_DIR}/README.md" \
  "${RADIUS_DIR}/app.bicep" \
  "${RADIUS_DIR}/bicepconfig.json" \
  "${RADIUS_DIR}/.rad/rad.yaml"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing generated state 005 artifact: ${required}"
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

echo "[info] state 005 radius artifacts ready at ${RADIUS_DIR}"
echo "[info] generated radius model: ${RADIUS_DIR}/app.bicep"
if command -v rad >/dev/null 2>&1; then
  echo "[info] radius CLI detected: $(rad version | head -n 1)"
  if (( DRY_RUN == 0 )); then
    echo "[hint] optionally run: (cd ${RADIUS_DIR} && rad run app.bicep)"
  fi
else
  echo "[info] radius CLI not found; runtime remains on state 004 Kubernetes path"
fi

echo "[done] state 005 radius-kubernetes platform started (runtime inherited from state 004)"
