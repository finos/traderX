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

STATE_DIR="${GENERATED_ROOT}/code/target-generated/fdc3-intent-interoperability"
SAIL_DIR="${STATE_DIR}/sail"
SAIL_COMPOSE_FILE="${SAIL_DIR}/docker-compose.yml"
SAIL_PROJECT_NAME="${SAIL_PROJECT_NAME:-traderx-state-014-sail}"
SAIL_HTTP_PORT="${SAIL_HTTP_PORT:-8090}"
SAIL_INTENT_LAUNCHER_PORT="${SAIL_INTENT_LAUNCHER_PORT:-4040}"
SAIL_TRADINGVIEW_PORT="${SAIL_TRADINGVIEW_PORT:-4023}"
SAIL_PRICER_PORT="${SAIL_PRICER_PORT:-4020}"
SAIL_RUNTIME_APPD="${SAIL_DIR}/runtime-cache/FDC3-Sail/packages/sail-web/fixtures/traderx-appd.json"

WITH_SAIL=0
K8S_PROVIDER="${K8S_PROVIDER:-kind}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-traderx-state-014}"
MINIKUBE_PROFILE=""

while (( "$#" )); do
  case "$1" in
    --with-sail)
      WITH_SAIL=1
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
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --with-sail --provider <kind|minikube> --cluster-name <name> --minikube-profile <name>"
      exit 1
      ;;
  esac
  shift
done

status_args=(--provider "${K8S_PROVIDER}")
status_args+=(--cluster-name "${KIND_CLUSTER_NAME}")
if [[ -n "${MINIKUBE_PROFILE}" ]]; then
  status_args+=(--minikube-profile "${MINIKUBE_PROFILE}")
fi

"${REPO_ROOT}/scripts/status-state-012-platform-convergence-c3-generated.sh" "${status_args[@]}"

echo
echo "[status] state 014 artifacts"
for target in \
  "${STATE_DIR}/README.md" \
  "${SAIL_COMPOSE_FILE}" \
  "${SAIL_DIR}/bootstrap/run-sail.sh" \
  "${SAIL_DIR}/appd/traderx.appd.v2.json"; do
  if [[ -f "${target}" ]]; then
    echo "[ok] ${target}"
  else
    echo "[missing] ${target}"
  fi
done

if (( WITH_SAIL == 0 )); then
  echo "[info] Sail sidecar status skipped (use --with-sail to inspect runtime)"
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found (required for Sail sidecar status)"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin is required for Sail sidecar status"
  exit 1
fi

if [[ ! -f "${SAIL_COMPOSE_FILE}" ]]; then
  echo "[info] Sail compose file not found: ${SAIL_COMPOSE_FILE}"
  exit 0
fi

echo
echo "[status] Sail sidecar compose services"
docker compose -f "${SAIL_COMPOSE_FILE}" --project-name "${SAIL_PROJECT_NAME}" ps

http_code_for() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || true
}

echo
printf "%-24s %-8s %s\n" "endpoint" "http" "url"
printf "%-24s %-8s %s\n" "------------------------" "--------" "---"
printf "%-24s %-8s %s\n" "sail-ui" "$(http_code_for "http://localhost:${SAIL_HTTP_PORT}/")" "http://localhost:${SAIL_HTTP_PORT}/"
printf "%-24s %-8s %s\n" "traderx-launcher" "$(http_code_for "http://localhost:${SAIL_INTENT_LAUNCHER_PORT}/")" "http://localhost:${SAIL_INTENT_LAUNCHER_PORT}/"
printf "%-24s %-8s %s\n" "tradingview-chart" "$(http_code_for "http://localhost:${SAIL_TRADINGVIEW_PORT}/?mode=chart")" "http://localhost:${SAIL_TRADINGVIEW_PORT}/?mode=chart"
printf "%-24s %-8s %s\n" "pricer" "$(http_code_for "http://localhost:${SAIL_PRICER_PORT}/")" "http://localhost:${SAIL_PRICER_PORT}/"

if [[ -f "${SAIL_RUNTIME_APPD}" ]]; then
  app_count="$(rg -o '"appId"\s*:' "${SAIL_RUNTIME_APPD}" | wc -l | tr -d ' ')"
  traderx_count="$(rg -o '"appId"\s*:\s*"traderx-web"' "${SAIL_RUNTIME_APPD}" | wc -l | tr -d ' ')"
  echo "[info] sail-appd-file: ${SAIL_RUNTIME_APPD}"
  echo "[info] sail-appd-app-count: ${app_count}"
  echo "[info] sail-appd-traderx-records: ${traderx_count}"
else
  echo "[info] sail-appd-file not present yet: ${SAIL_RUNTIME_APPD}"
fi
