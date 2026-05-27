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
STATE_ID="007-observability-lgtm-compose"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-007}"
GRAFANA_PORT="${GRAFANA_PORT:-3001}"
COMPOSE_DIR="${GENERATED_ROOT}/code/target-generated/observability-lgtm-compose"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
DRY_RUN=0
SKIP_BUILD=0

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run --skip-build"
      exit 1
      ;;
  esac
  shift
done

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] docker compose plugin is required"
  exit 1
fi

if [[ -z "${DOCKER_BUILDKIT:-}" ]]; then
  export DOCKER_BUILDKIT=1
  echo "[info] DOCKER_BUILDKIT not set; defaulting to 1 for Docker cache mounts"
fi

if [[ "${TRADERX_SKIP_GENERATE:-0}" != "1" ]]; then
  bash "${REPO_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"
else
  echo "[info] skipping state generation for ${STATE_ID} (TRADERX_SKIP_GENERATE=1)"
fi

[[ -f "${COMPOSE_FILE}" ]] || {
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
}

if (( DRY_RUN == 1 )); then
  if (( SKIP_BUILD == 1 )); then
    echo "[dry-run] docker compose -f ${COMPOSE_FILE} --project-name ${COMPOSE_PROJECT_NAME} up -d --no-build"
  else
    echo "[dry-run] docker compose -f ${COMPOSE_FILE} --project-name ${COMPOSE_PROJECT_NAME} up -d --build"
  fi
  echo "[done] dry run complete for state 007"
  exit 0
fi

if (( SKIP_BUILD == 1 )); then
  docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --no-build
else
  docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --build
fi

wait_for_postgres() {
  local attempts=90
  local i
  for ((i=1; i<=attempts; i++)); do
    if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" exec -T database \
      pg_isready -U traderx -d traderx >/dev/null 2>&1; then
      echo "[ready] postgres database"
      return 0
    fi
    sleep 2
  done
  echo "[error] timeout waiting for postgres readiness"
  return 1
}

wait_for_http() {
  local name="$1"
  local url="$2"
  local attempts=90
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

wait_for_postgres || exit 1
wait_for_http "reference-data" "http://localhost:18085/stocks" || exit 1
wait_for_http "ingress" "http://localhost:8080/health" || exit 1
wait_for_http "grafana" "http://localhost:${GRAFANA_PORT}/api/health" || exit 1
wait_for_http "prometheus" "http://localhost:9090/-/ready" || exit 1
wait_for_http "loki" "http://localhost:3100/ready" || exit 1
wait_for_http "tempo" "http://localhost:3200/ready" || exit 1
wait_for_http "otel-collector-health" "http://localhost:13133/" || exit 1

bash "${REPO_ROOT}/scripts/start-grafana-traderx-dashboards.sh" \
  "http://localhost:${GRAFANA_PORT}" \
  "admin" \
  "admin" \
  "TraderX" \
  "traderx-obs-006-overview" || true

echo "[done] state 007 observability runtime started"
echo "[ui] http://localhost:8080"
echo "[api-explorer] http://localhost:8080/api/docs"
echo "[grafana] http://localhost:${GRAFANA_PORT} (local login credentials)"
