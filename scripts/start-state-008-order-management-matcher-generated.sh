#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"
STATE_ID="008-order-management-matcher"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-008}"
COMPOSE_DIR="${GENERATED_ROOT}/code/target-generated/order-management-matcher"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
DRY_RUN=0

while (( "$#" )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "[error] unknown argument: $1"
      echo "[hint] supported: --dry-run"
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

bash "${REPO_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"

[[ -f "${COMPOSE_FILE}" ]] || {
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
}

if (( DRY_RUN == 1 )); then
  echo "[dry-run] docker compose -f ${COMPOSE_FILE} --project-name ${COMPOSE_PROJECT_NAME} up -d --build"
  echo "[done] dry run complete for state 008"
  exit 0
fi

docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --build

# Grafana only provisions file-based dashboards on startup.
# Restart once after compose up so updated generated dashboards are always loaded.
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" restart grafana >/dev/null 2>&1 || true

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
wait_for_http "nats-monitor" "http://localhost:8222/varz" || exit 1
wait_for_http "price-publisher" "http://localhost:18100/health" || exit 1
wait_for_http "order-matcher-health" "http://localhost:18110/health" || exit 1
wait_for_http "ingress" "http://localhost:8080/health" || exit 1
wait_for_http "grafana" "http://localhost:3000/api/health" || exit 1
wait_for_http "prometheus" "http://localhost:9090/-/ready" || exit 1
wait_for_http "loki" "http://localhost:3100/ready" || exit 1
wait_for_http "tempo" "http://localhost:3200/ready" || exit 1
wait_for_http "otel-collector-health" "http://localhost:13133/" || exit 1

bash "${REPO_ROOT}/scripts/star-grafana-traderx-dashboards.sh" \
  "http://localhost:3000" \
  "admin" \
  "admin" \
  "TraderX" \
  "traderx-obs-008-order-management" || true

echo "[done] state 008 order-management runtime started"
echo "[ui] http://localhost:8080"
echo "[grafana] http://localhost:3000 (admin/admin)"
