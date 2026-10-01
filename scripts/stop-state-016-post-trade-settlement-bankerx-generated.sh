#!/usr/bin/env bash
set -euo pipefail

# State 016 stop script — inverse of
# scripts/start-state-016-post-trade-settlement-bankerx-generated.sh.
# Static acceptance mode leaves only the python http.server to the operator
# (Ctrl+C); the Sail runtime mode stops the Sail sidecar and delegates the C3
# baseline teardown.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi

STATE_DIR="${GENERATED_ROOT}/code/target-generated/fdc3-intent-interoperability"
SAIL_DIR="${STATE_DIR}/sail"
SAIL_COMPOSE_FILE="${SAIL_DIR}/docker-compose.yml"
SAIL_PROJECT_NAME="${SAIL_PROJECT_NAME:-traderx-state-016-sail}"

DELETE_CLUSTER=0
WITH_SAIL=1
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-traderx-state-016}"

while (( "$#" )); do
  case "$1" in
    --delete-cluster)
      DELETE_CLUSTER=1
      ;;
    --without-sail)
      WITH_SAIL=0
      ;;
    --provider)
      K8S_PROVIDER="${2:-}"
      shift
      ;;
    --cluster-name)
      KIND_CLUSTER_NAME="${2:-}"
      shift
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --delete-cluster --without-sail --provider <kind|minikube> --cluster-name <name>"
      exit 1
      ;;
  esac
  shift
done

if (( WITH_SAIL == 1 )); then
  if ! command -v docker >/dev/null 2>&1; then
    echo "[error] docker command not found (required to stop the Sail sidecar)"
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "[error] docker compose plugin is required to stop the Sail sidecar"
    exit 1
  fi
  if [[ -f "${SAIL_COMPOSE_FILE}" ]]; then
    docker compose -f "${SAIL_COMPOSE_FILE}" --project-name "${SAIL_PROJECT_NAME}" down --remove-orphans
    echo "[done] Sail sidecar stopped (receiver overlay is a runtime-directory merge — no durable change)"
  else
    echo "[info] Sail compose file not found; nothing to stop: ${SAIL_COMPOSE_FILE}"
  fi
fi

stop_args=(--provider "${K8S_PROVIDER}")
stop_args+=(--cluster-name "${KIND_CLUSTER_NAME}")
if (( DELETE_CLUSTER == 1 )); then
  stop_args+=(--delete-cluster)
fi
"${REPO_ROOT}/scripts/stop-state-012-platform-convergence-c3-generated.sh" "${stop_args[@]}"
echo "[done] state 016 stop sequence complete"