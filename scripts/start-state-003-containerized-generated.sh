#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ID="003-containerized-compose-runtime"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-003}"
COMPOSE_DIR="${REPO_ROOT}/generated/code/target-generated/containerized-compose"
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

bash "${REPO_ROOT}/pipeline/generate-state.sh" "${STATE_ID}"

[[ -f "${COMPOSE_FILE}" ]] || {
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  exit 1
}

if (( DRY_RUN == 1 )); then
  echo "[dry-run] docker compose -f ${COMPOSE_FILE} --project-name ${COMPOSE_PROJECT_NAME} up -d --build"
  echo "[done] dry run complete for state 003"
  exit 0
fi

docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" up -d --build

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

wait_for_http "database-web" "http://localhost:18084" || exit 1
wait_for_http "reference-data" "http://localhost:18085/stocks" || exit 1
wait_for_http "account-service" "http://localhost:18088/account/22214" || exit 1
wait_for_http "position-service" "http://localhost:18090/positions/22214" || exit 1
wait_for_http "trade-service" "http://localhost:18092/swagger-ui.html" || exit 1
wait_for_http "ingress" "http://localhost:8080/health" || exit 1
wait_for_http "ingress-ui" "http://localhost:8080" || exit 1

echo "[done] state 003 containerized compose runtime started"
echo "[ui] http://localhost:8080"
