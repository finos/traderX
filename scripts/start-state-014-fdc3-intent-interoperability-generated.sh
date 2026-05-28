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

STATE_ID="014-fdc3-intent-interoperability"
STATE_DIR="${GENERATED_ROOT}/code/target-generated/fdc3-intent-interoperability"
SAIL_DIR="${STATE_DIR}/sail"
SAIL_COMPOSE_FILE="${SAIL_DIR}/docker-compose.yml"
SAIL_PROJECT_NAME="${SAIL_PROJECT_NAME:-traderx-state-014-sail}"
SAIL_HTTP_PORT="${SAIL_HTTP_PORT:-8090}"
SAIL_RUNTIME_APPD="${SAIL_DIR}/runtime-cache/FDC3-Sail/packages/fdc3-example-apps/directory/generated/fdc3-example-apps.json"

DRY_RUN=0
SKIP_BUILD=0
RECREATE_CLUSTER=0
RUN_TILT=0
WITH_SAIL=1
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-traderx-state-014}"
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
    --with-sail)
      WITH_SAIL=1
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
      echo "[hint] supported: --dry-run --skip-build --recreate-cluster --run-tilt --with-sail --without-sail --provider <kind|minikube> --cluster-name <name> --minikube-profile <name> --minikube-driver <name>"
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
  "${SAIL_COMPOSE_FILE}" \
  "${SAIL_DIR}/bootstrap/run-sail.sh" \
  "${SAIL_DIR}/bootstrap/apply-tradingview-overrides.sh" \
  "${SAIL_DIR}/bootstrap/sail-pin.env" \
  "${SAIL_DIR}/bootstrap/overrides/web/default-client-state.json" \
  "${SAIL_DIR}/bootstrap/overrides/traderx-intent-launcher/src/main.tsx" \
  "${SAIL_DIR}/bootstrap/merge-traderx-appd.sh" \
  "${SAIL_DIR}/appd/traderx.appd.v2.json"; do
  [[ -f "${required}" ]] || {
    echo "[error] missing generated state 014 artifact: ${required}"
    exit 1
  }
done

start_args=(--provider "${K8S_PROVIDER}")
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
if (( RUN_TILT == 1 )); then
  start_args+=(--run-tilt)
fi
if [[ -n "${MINIKUBE_PROFILE}" ]]; then
  start_args+=(--minikube-profile "${MINIKUBE_PROFILE}")
fi
if [[ -n "${MINIKUBE_DRIVER}" ]]; then
  start_args+=(--minikube-driver "${MINIKUBE_DRIVER}")
fi

# Preserve published-image controls for downstream runtime scripts and GHCR bundle validation.
if [[ "${TRADERX_USE_PUBLISHED_IMAGES:-0}" == "1" ]]; then
  export TRADERX_USE_PUBLISHED_IMAGES=1
  export TRADERX_PUBLISHED_NAMESPACE="${TRADERX_PUBLISHED_NAMESPACE:-}"
  export TRADERX_PUBLISHED_TAG="${TRADERX_PUBLISHED_TAG:-}"
fi

runtime_scripts_dir="${REPO_ROOT}/scripts"
state_012_start_script="${runtime_scripts_dir}/start-state-012-platform-convergence-c3-generated.sh"
TRADERX_SKIP_GENERATE=1 "${state_012_start_script}" "${start_args[@]}"

if (( WITH_SAIL == 0 )); then
  echo "[done] state 014 started on C3 baseline runtime (Sail sidecar disabled)"
  echo "[hint] default is Sail enabled; use --without-sail only for backend-only runtime checks"
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found (required for Sail sidecar)"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin is required for Sail sidecar"
  exit 1
fi

if (( DRY_RUN == 1 )); then
  echo "[dry-run] docker compose -f ${SAIL_COMPOSE_FILE} --project-name ${SAIL_PROJECT_NAME} up -d"
  echo "[done] dry run complete for state 014"
  exit 0
fi

echo "[start] launching Sail sidecar (${SAIL_PROJECT_NAME})"
docker compose -f "${SAIL_COMPOSE_FILE}" --project-name "${SAIL_PROJECT_NAME}" up -d

wait_for_http() {
  local name="$1"
  local url="$2"
  local attempts=150
  local i
  for ((i=1; i<=attempts; i++)); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      echo "[ready] ${name} ${url}"
      return 0
    fi
    sleep 2
  done
  echo "[error] timeout waiting for ${name} at ${url}"
  return 1
}

wait_for_http "sail-ui" "http://localhost:${SAIL_HTTP_PORT}/html/" || exit 1

if [[ -f "${SAIL_RUNTIME_APPD}" ]]; then
  if rg -q '"appId"\s*:\s*"traderx-web"' "${SAIL_RUNTIME_APPD}"; then
    echo "[ready] TraderX app directory record seeded in Sail"
  else
    echo "[warn] Sail app directory is present but TraderX record not detected yet: ${SAIL_RUNTIME_APPD}"
  fi
else
  echo "[warn] Sail generated app directory not found yet: ${SAIL_RUNTIME_APPD}"
fi

echo "[done] state 014 demo runtime started"
echo "[ui] TraderX: http://localhost:8080"
echo "[ui] Sail: http://localhost:${SAIL_HTTP_PORT}"
