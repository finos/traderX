#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
ORIGIN="${2:-http://localhost:8080}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-011}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/generated/code/target-generated/observability-lgtm-compose/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 011-observability-lgtm-compose"
  exit 1
fi

echo "[check] compose services running"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
running_services="$(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | wc -l | tr -d ' ')"
if [[ "${running_services}" -lt 17 ]]; then
  echo "[error] expected 17+ running services, got ${running_services}"
  exit 1
fi

if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --services | grep -q '^nats-broker$'; then
  echo "[error] state 011 should remain on trade-feed and not include nats-broker"
  exit 1
fi

echo "[check] observability endpoints"
for endpoint in \
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
if [[ "${target_count}" -lt 8 ]]; then
  echo "[error] expected 8+ active probe targets, got ${target_count}"
  exit 1
fi
echo "[info] active traderx probe targets=${target_count}"

echo "[check] baseline behavior under observability runtime"
"${REPO_ROOT}/scripts/test-reference-data-overlay.sh" "${ORIGIN}" "http://localhost:18085"
"${REPO_ROOT}/scripts/test-database-overlay.sh" "18082" "18083" "http://localhost:18084/" "http://localhost:18088/account/22214"
"${REPO_ROOT}/scripts/test-people-service-overlay.sh" "${ORIGIN}" "http://localhost:18089" "http://localhost:18088/accountuser/"
"${REPO_ROOT}/scripts/test-account-service-overlay.sh" "${ORIGIN}" "http://localhost:18088"
"${REPO_ROOT}/scripts/test-position-service-overlay.sh" "${ORIGIN}" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-trade-feed-overlay.sh" "http://localhost:18086"
"${REPO_ROOT}/scripts/test-trade-processor-overlay.sh" "${ORIGIN}" "http://localhost:18091" "http://localhost:18090" "http://localhost:18086"
"${REPO_ROOT}/scripts/test-trade-service-overlay.sh" "${ORIGIN}" "http://localhost:18092" "http://localhost:18090"
"${REPO_ROOT}/scripts/test-realtime-account-stream-overlay.sh" "http://localhost:18092" "${INGRESS_URL}" "22214"
"${REPO_ROOT}/scripts/test-web-angular-overlay.sh" "${INGRESS_URL}"

echo "[done] state 011 observability runtime smoke tests passed"
