#!/usr/bin/env bash
set -euo pipefail

EDGE_URL="${1:-http://localhost:18080}"
ORIGIN="${2:-http://localhost:18080}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-003}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/generated/code/target-generated/containerized-compose/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 003-containerized-compose-runtime"
  exit 1
fi

echo "[check] compose services running"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
running_services="$(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | wc -l | tr -d ' ')"
if [[ "${running_services}" -lt 10 ]]; then
  echo "[error] expected 10+ running services, got ${running_services}"
  exit 1
fi

echo "[check] edge-proxy behavior compatibility"
"${REPO_ROOT}/scripts/test-state-002-edge-proxy.sh" "${EDGE_URL}"

echo "[check] baseline service smoke suite in containerized runtime"
"${REPO_ROOT}/scripts/test-reference-data-overlay.sh" "${ORIGIN}" "http://localhost:18085"
"${REPO_ROOT}/scripts/test-database-overlay.sh" "18082" "18083" "http://localhost:18084/" "http://localhost:18088/account/22214"
"${REPO_ROOT}/scripts/test-people-service-overlay.sh" "${ORIGIN}" "http://localhost:18089" "http://localhost:18088/accountuser/"
"${REPO_ROOT}/scripts/test-account-service-overlay.sh" "${ORIGIN}" "http://localhost:18088"
"${REPO_ROOT}/scripts/test-position-service-overlay.sh" "${ORIGIN}" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-trade-feed-overlay.sh" "http://localhost:18086"
"${REPO_ROOT}/scripts/test-trade-processor-overlay.sh" "${ORIGIN}" "http://localhost:18091" "http://localhost:18090" "http://localhost:18086"
"${REPO_ROOT}/scripts/test-trade-service-overlay.sh" "${ORIGIN}" "http://localhost:18092" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-web-angular-overlay.sh" "${EDGE_URL}"

echo "[done] state 003 containerized compose smoke tests passed"
