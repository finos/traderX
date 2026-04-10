#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="${1:-http://localhost:8080}"
ORIGIN="${2:-http://localhost:8080}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-007}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    exec "${LOCAL_RUNTIME_SCRIPT}" "$@"
  fi
fi
COMPOSE_FILE="${GENERATED_ROOT}/code/target-generated/observability-lgtm-compose/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 007-observability-lgtm-compose"
  exit 1
fi

echo "[check] compose services running"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
running_services="$(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | wc -l | tr -d ' ')"
if [[ "${running_services}" -lt 17 ]]; then
  echo "[error] expected 17+ running services, got ${running_services}"
  exit 1
fi

if ! docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --services | grep -q '^nats-broker$'; then
  echo "[error] state 007 must include nats-broker from state 006 lineage"
  exit 1
fi

if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --services | grep -q '^trade-feed$'; then
  echo "[error] state 007 must not include legacy trade-feed service"
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
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-007}"
  "${REPO_ROOT}/scripts/test-state-006-messaging-nats-replacement.sh" "${INGRESS_URL}" "${ORIGIN}"

echo "[done] state 007 observability runtime smoke tests passed"
