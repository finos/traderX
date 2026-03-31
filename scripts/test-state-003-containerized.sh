#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
ORIGIN="${2:-http://localhost:8080}"
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

echo "[check] nginx ingress health endpoint"
health_headers="$(curl -sS -i "${INGRESS_URL}/health" | sed -n '1,20p')"
echo "${health_headers}"
printf '%s\n' "${health_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from ingress /health"
  exit 1
}

echo "[check] ingress UI root"
ui_headers="$(curl -sS -i "${INGRESS_URL}/" | sed -n '1,20p')"
echo "${ui_headers}"
printf '%s\n' "${ui_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from ingress UI root"
  exit 1
}

echo "[check] ingress account-service proxy endpoint"
account_headers="$(curl -sS -i "${INGRESS_URL}/account-service/account/22214" | sed -n '1,25p')"
echo "${account_headers}"
printf '%s\n' "${account_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from ingress proxied account-service endpoint"
  exit 1
}

echo "[check] ingress reference-data proxy endpoint"
stocks_headers="$(curl -sS -i "${INGRESS_URL}/reference-data/stocks" | sed -n '1,25p')"
echo "${stocks_headers}"
printf '%s\n' "${stocks_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from ingress proxied reference-data endpoint"
  exit 1
}

echo "[check] ingress trade-service unknown ticker validation"
status_code="$(curl -sS -o /tmp/traderx-state-003-trade.out -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -d '{"security":"NOTREAL","quantity":1,"accountId":22214,"side":"Buy"}' \
  "${INGRESS_URL}/trade-service/trade")"
cat /tmp/traderx-state-003-trade.out
echo
rm -f /tmp/traderx-state-003-trade.out
if [[ "${status_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown ticker through ingress, got ${status_code}"
  exit 1
fi

echo "[check] baseline service smoke suite in containerized runtime"
"${REPO_ROOT}/scripts/test-reference-data-overlay.sh" "${ORIGIN}" "http://localhost:18085"
"${REPO_ROOT}/scripts/test-database-overlay.sh" "18082" "18083" "http://localhost:18084/" "http://localhost:18088/account/22214"
"${REPO_ROOT}/scripts/test-people-service-overlay.sh" "${ORIGIN}" "http://localhost:18089" "http://localhost:18088/accountuser/"
"${REPO_ROOT}/scripts/test-account-service-overlay.sh" "${ORIGIN}" "http://localhost:18088"
"${REPO_ROOT}/scripts/test-position-service-overlay.sh" "${ORIGIN}" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-trade-feed-overlay.sh" "http://localhost:18086"
"${REPO_ROOT}/scripts/test-trade-processor-overlay.sh" "${ORIGIN}" "http://localhost:18091" "http://localhost:18090" "http://localhost:18086"
"${REPO_ROOT}/scripts/test-trade-service-overlay.sh" "${ORIGIN}" "http://localhost:18092" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-realtime-account-stream-overlay.sh" "http://localhost:18092" "http://localhost:18086" "22214"
"${REPO_ROOT}/scripts/test-web-angular-overlay.sh" "${INGRESS_URL}"

echo "[done] state 003 containerized compose smoke tests passed"
