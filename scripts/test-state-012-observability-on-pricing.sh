#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
ORIGIN="${2:-http://localhost:8080}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-012}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/generated/code/target-generated/observability-on-pricing/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 012-observability-on-pricing"
  exit 1
fi

echo "[check] compose services running"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
running_services="$(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | wc -l | tr -d ' ')"
if [[ "${running_services}" -lt 18 ]]; then
  echo "[error] expected 18+ running services, got ${running_services}"
  exit 1
fi

if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --services | grep -q '^trade-feed$'; then
  echo "[error] state 012 should inherit NATS path and must not include trade-feed"
  exit 1
fi

echo "[check] pricing + observability endpoints"
for endpoint in \
  "http://localhost:18100/health" \
  "http://localhost:8222/varz" \
  "http://localhost:3000/api/health" \
  "http://localhost:9090/-/ready" \
  "http://localhost:3100/ready" \
  "http://localhost:3200/ready" \
  "http://localhost:13133/"; do
  headers="$(curl -sS -i "${endpoint}" | sed -n '1,20p')"
  echo "${headers}"
  printf '%s\n' "${headers}" | grep -q "200" || {
    echo "[error] expected 200 from ${endpoint}"
    exit 1
  }
done

echo "[check] grafana provisioned dashboards"
dashboard_count="$(
  curl -sS -u admin:admin "http://localhost:3000/api/search?query=TraderX" \
  | jq 'length'
)"
if [[ "${dashboard_count}" -lt 1 ]]; then
  echo "[error] expected at least one provisioned Grafana dashboard, got ${dashboard_count}"
  exit 1
fi
echo "[info] grafana dashboards=${dashboard_count}"

echo "[check] prometheus traderx probe targets discovered"
target_count="$(
  curl -sS "http://localhost:9090/api/v1/targets" \
  | jq '[.data.activeTargets[] | select(.labels.job=="traderx-http-probe")] | length'
)"
if [[ "${target_count}" -lt 10 ]]; then
  echo "[error] expected 10+ active probe targets, got ${target_count}"
  exit 1
fi
echo "[info] active traderx probe targets=${target_count}"

echo "[check] ingress websocket upgrade route to NATS"
ws_headers="$(
  curl -sS -i --max-time 5 \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "${INGRESS_URL}/nats-ws" 2>/dev/null | sed -n '1,30p' || true
)"
echo "${ws_headers}"
printf '%s\n' "${ws_headers}" | grep -Eq "HTTP/1\\.[01] 101|HTTP/2 101" || {
  echo "[error] expected websocket 101 response from ${INGRESS_URL}/nats-ws"
  exit 1
}

echo "[check] baseline component smoke suite in state 012 runtime"
"${REPO_ROOT}/scripts/test-reference-data-overlay.sh" "${ORIGIN}" "http://localhost:18085" "20"
"${REPO_ROOT}/scripts/test-database-overlay.sh" "18082" "18083" "http://localhost:18084/" "http://localhost:18088/account/22214"
"${REPO_ROOT}/scripts/test-people-service-overlay.sh" "${ORIGIN}" "http://localhost:18089" "http://localhost:18088/accountuser/"
"${REPO_ROOT}/scripts/test-account-service-overlay.sh" "${ORIGIN}" "http://localhost:18088"
"${REPO_ROOT}/scripts/test-position-service-overlay.sh" "${ORIGIN}" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-trade-service-overlay.sh" "${ORIGIN}" "http://localhost:18092" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-web-angular-overlay.sh" "${INGRESS_URL}"

echo "[done] state 012 observability+pricing runtime smoke tests passed"
