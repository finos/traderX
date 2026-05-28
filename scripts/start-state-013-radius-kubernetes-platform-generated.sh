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
STATE_ID="013-radius-kubernetes-platform"
STATE_DIR="${GENERATED_ROOT}/code/target-generated/radius-kubernetes-platform"
RADIUS_DIR="${STATE_DIR}/radius"

DRY_RUN=0
SKIP_BUILD=0
RECREATE_CLUSTER=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-traderx-state-013}"
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
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
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
      echo "[hint] supported: --dry-run --skip-build --recreate-cluster --provider <kind|minikube> --cluster-name <name> --minikube-profile <name> --minikube-driver <name>"
      exit 1
      ;;
  esac
  shift
done

if [[ "${TRADERX_SKIP_GENERATE:-0}" != "1" ]]; then
  generate_state_script="${REPO_ROOT}/pipeline/${TRADERX_GENERATE_STATE_SCRIPT_BASENAME:-generate-state.sh}"
  if [[ -f "${generate_state_script}" ]]; then
    bash "${generate_state_script}" "${STATE_ID}"
  else
    echo "[warn] generation script not found: ${generate_state_script}; continuing with existing artifacts"
  fi
else
  echo "[info] skipping state generation for ${STATE_ID} (TRADERX_SKIP_GENERATE=1)"
fi

for required in \
  "${STATE_DIR}/README.md" \
  "${RADIUS_DIR}/app.bicep" \
  "${RADIUS_DIR}/bicepconfig.json" \
  "${RADIUS_DIR}/.rad/rad.yaml"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing generated state 013 artifact: ${required}"
    exit 1
  }
done

start_args=(--provider "${K8S_PROVIDER}")
start_args+=(--skip-generate)
start_args+=(--cluster-name "${KIND_CLUSTER_NAME}")
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

runtime_scripts_dir="${REPO_ROOT}/scripts"
state_010_start_script="${runtime_scripts_dir}/start-state-010-kubernetes-runtime-generated.sh"
"${state_010_start_script}" "${start_args[@]}"

echo "[info] state 013 radius artifacts ready at ${RADIUS_DIR}"
echo "[info] generated radius model: ${RADIUS_DIR}/app.bicep"
if command -v rad >/dev/null 2>&1; then
  echo "[info] radius CLI detected: $(rad version | head -n 1)"
  if (( DRY_RUN == 0 )); then
    echo "[hint] optionally run: (cd ${RADIUS_DIR} && rad run app.bicep)"
  fi
else
  echo "[info] radius CLI not found; runtime remains on state 010 Kubernetes path"
fi

echo "[done] state 013 radius-kubernetes platform started (runtime inherited from state 010)"
