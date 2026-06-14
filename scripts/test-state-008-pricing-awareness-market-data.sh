#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="http://localhost:8080"
ORIGIN="http://localhost:8080"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-008}"
GRAFANA_PORT="${GRAFANA_PORT:-3001}"
GRAFANA_ADMIN_USER="${TRADERX_GRAFANA_ADMIN_USER:-traderx-admin}"
GRAFANA_ADMIN_PASSWORD="${TRADERX_GRAFANA_ADMIN_PASSWORD:-traderx-state-008}"
GRAFANA_ADMIN_AUTH="${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_ROOT="${TRADERX_GENERATED_ROOT:-${REPO_ROOT}/generated}"
SKIP_MESSAGING=0

while (( "$#" )); do
  case "$1" in
    --skip-messaging)
      SKIP_MESSAGING=1
      ;;
    *)
      if [[ "${INGRESS_URL}" == "http://localhost:8080" ]]; then
        INGRESS_URL="$1"
      elif [[ "${ORIGIN}" == "http://localhost:8080" ]]; then
        ORIGIN="$1"
      else
        echo "[error] unknown argument: $1"
        echo "[hint] usage: $0 [INGRESS_URL] [ORIGIN] [--skip-messaging]"
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    args=("${INGRESS_URL}" "${ORIGIN}")
    if [[ "${SKIP_MESSAGING}" -eq 1 ]]; then
      args+=("--skip-messaging")
    fi
    exec "${LOCAL_RUNTIME_SCRIPT}" "${args[@]}"
  fi
fi
COMPOSE_FILE="${GENERATED_ROOT}/code/target-generated/pricing-awareness-market-data/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 008-pricing-awareness-market-data"
  exit 1
fi

check_message_bus_health_endpoint() {
  local endpoint="$1"
  local component="$2"
  local payload
  payload="$(curl -fsS "${endpoint}")"

  local top_status
  top_status="$(echo "${payload}" | jq -r '.status // empty')"
  if [[ "${top_status}" != "ok" ]]; then
    echo "[error] ${component} system health is not ok at ${endpoint}: status=${top_status}"
    echo "${payload}"
    exit 1
  fi

  local statuses
  statuses="$(echo "${payload}" | jq -r '
    if (.messageBus | type) != "object" then
      empty
    elif ((.messageBus | has("publisher")) or (.messageBus | has("subscriber"))) then
      [.messageBus.publisher.status?, .messageBus.subscriber.status?] | .[]
    else
      .messageBus.status // empty
    end
  ')"

  if [[ -z "${statuses//[$'\n\r\t ']}" ]]; then
    echo "[error] ${component} system health missing messageBus status payload at ${endpoint}"
    echo "${payload}"
    exit 1
  fi

  while IFS= read -r bus_status; do
    [[ -z "${bus_status}" ]] && continue
    if [[ "${bus_status}" != "connected" ]]; then
      echo "[error] ${component} message bus is not connected at ${endpoint}: status=${bus_status}"
      echo "${payload}"
      exit 1
    fi
  done <<< "${statuses}"
}

echo "[check] compose services running"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps
running_services="$(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | wc -l | tr -d ' ')"
if [[ "${running_services}" -lt 11 ]]; then
  echo "[error] expected 11+ running services, got ${running_services}"
  exit 1
fi

if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --services | grep -q '^trade-feed$'; then
  echo "[error] state 008 runtime must not contain trade-feed service"
  exit 1
fi

echo "[check] postgres readiness"
docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" exec -T database \
  pg_isready -U traderx -d traderx

echo "[check] postgres baseline data loaded"
accounts_count="$(docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" exec -T database \
  psql -U traderx -d traderx -tAc "select count(*) from accounts;" | tr -d '[:space:]')"
if [[ -z "${accounts_count}" || "${accounts_count}" -lt 7 ]]; then
  echo "[error] expected baseline accounts in postgres, got count=${accounts_count:-0}"
  exit 1
fi

echo "[check] price-publisher quote endpoint"
price_headers="$(curl -sS -i "http://localhost:18100/prices/IBM" | sed -n '1,30p')"
echo "${price_headers}"
printf '%s\n' "${price_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from price-publisher /prices/IBM"
  exit 1
}
curl -sS "http://localhost:18100/prices/IBM" | jq -e '.ticker == "IBM" and (.price|type=="number")' >/dev/null || {
  echo "[error] price-publisher quote payload missing expected fields"
  exit 1
}

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

echo "[check] api explorer pubsub inspector contract"
bash "${REPO_ROOT}/scripts/test-api-explorer-pubsub-inspector.sh" \
  "${INGRESS_URL}" \
  "specs/008-pricing-awareness-market-data/system/messaging-subject-map.md"

echo "[check] NATS broker monitor endpoint"
nats_varz_headers="$(curl -sS -i "http://localhost:8222/varz" | sed -n '1,30p')"
echo "${nats_varz_headers}"
printf '%s\n' "${nats_varz_headers}" | grep -q "HTTP/1.1 200" || {
  echo "[error] expected 200 from NATS monitor endpoint"
  exit 1
}
curl -sS "http://localhost:8222/varz" | jq -e '.server_id and .max_payload and .proto' >/dev/null || {
  echo "[error] NATS /varz payload missing required keys"
  exit 1
}

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

echo "[check] message bus connectivity pre-check via /system/health"
check_message_bus_health_endpoint "${INGRESS_URL}/trade-service/system/health" "trade-service"
check_message_bus_health_endpoint "${INGRESS_URL}/trade-processor/system/health" "trade-processor"

if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | grep -q '^prometheus$'; then
  echo "[check] prometheus message bus connectivity metric is queryable"
  message_bus_sample_count="$(
    curl -sS --get "http://localhost:9090/api/v1/query" \
      --data-urlencode 'query=traderx_messagebus_connected' \
    | jq -r '.data.result | length'
  )"
  if [[ "${message_bus_sample_count}" -lt 3 ]]; then
    echo "[error] expected 3+ traderx_messagebus_connected samples in Prometheus, got ${message_bus_sample_count}"
    exit 1
  fi
  echo "[info] traderx_messagebus_connected series=${message_bus_sample_count}"
else
  echo "[info] prometheus service is not part of state 008 compose; skipping Prometheus metric assertions"
fi

if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | grep -q '^grafana$'; then
  echo "[check] grafana includes message bus connectivity dashboard/panel query"
  dashboard_uids_raw="$(
    curl -sS -u "${GRAFANA_ADMIN_AUTH}" "http://localhost:${GRAFANA_PORT}/api/search?query=TraderX&type=dash-db" \
    | jq -r '.[].uid'
  )"
  message_bus_dashboard_uid=""
  while IFS= read -r dashboard_uid; do
    [[ -z "${dashboard_uid}" ]] && continue
    dashboard_payload="$(curl -sS -u "${GRAFANA_ADMIN_AUTH}" "http://localhost:${GRAFANA_PORT}/api/dashboards/uid/${dashboard_uid}")"
    dashboard_text="$(echo "${dashboard_payload}" | jq -r '.dashboard | tostring')"
    if printf '%s\n' "${dashboard_text}" | rg -q 'traderx_messagebus_connected'; then
      message_bus_dashboard_uid="${dashboard_uid}"
      break
    fi
  done <<< "${dashboard_uids_raw}"
  if [[ -z "${message_bus_dashboard_uid}" ]]; then
    echo "[error] no provisioned TraderX dashboard includes traderx_messagebus_connected query"
    exit 1
  fi
  echo "[info] grafana dashboard uid=${message_bus_dashboard_uid} includes message bus connectivity query"
else
  echo "[info] grafana service is not part of state 008 compose; skipping dashboard assertions"
fi

if docker compose -f "${COMPOSE_FILE}" --project-name "${COMPOSE_PROJECT_NAME}" ps --status running --services | grep -q '^grafana$'; then
  echo "[check] grafana loki datasource has non-empty pricing/runtime log streams"
  now_ms=$(($(date +%s) * 1000))
  from_ms=$((now_ms - 15 * 60 * 1000))
  loki_total_query_result="$(
    curl -sS -u "${GRAFANA_ADMIN_AUTH}" -H 'Content-Type: application/json' -X POST "http://localhost:${GRAFANA_PORT}/api/ds/query" \
      -d "{\"from\":\"${from_ms}\",\"to\":\"${now_ms}\",\"queries\":[{\"refId\":\"A\",\"datasource\":{\"uid\":\"loki\",\"type\":\"loki\"},\"expr\":\"sum(count_over_time({compose_project=\\\"${COMPOSE_PROJECT_NAME}\\\"}[5m]))\",\"queryType\":\"range\",\"intervalMs\":1000,\"maxDataPoints\":500}]}"
  )"
  loki_total_query_error="$(echo "${loki_total_query_result}" | jq -r '.results.A.error // empty')"
  loki_total_last="$(echo "${loki_total_query_result}" | jq -r '.results.A.frames[0].data.values[1][-1] // "0"')"
  if [[ -n "${loki_total_query_error}" ]]; then
    echo "[error] grafana loki query failed: ${loki_total_query_error}"
    exit 1
  fi
  if ! awk "BEGIN {exit !(${loki_total_last} > 0)}"; then
    echo "[error] expected non-empty Loki ingestion in last 5m, got ${loki_total_last}"
    exit 1
  fi

  echo "[check] dashboard service-filtered pricing pipeline logs are present"
  loki_service_query_result="$(
    curl -sS -u "${GRAFANA_ADMIN_AUTH}" -H 'Content-Type: application/json' -X POST "http://localhost:${GRAFANA_PORT}/api/ds/query" \
      -d "{\"from\":\"${from_ms}\",\"to\":\"${now_ms}\",\"queries\":[{\"refId\":\"A\",\"datasource\":{\"uid\":\"loki\",\"type\":\"loki\"},\"expr\":\"sum(count_over_time({compose_project=\\\"${COMPOSE_PROJECT_NAME}\\\",service=~\\\"price-publisher|trade-service|trade-processor|position-service|nats-broker|web-front-end-angular\\\"}[10m]))\",\"queryType\":\"range\",\"intervalMs\":1000,\"maxDataPoints\":500}]}"
  )"
  loki_service_query_error="$(echo "${loki_service_query_result}" | jq -r '.results.A.error // empty')"
  loki_service_last="$(echo "${loki_service_query_result}" | jq -r '.results.A.frames[0].data.values[1][-1] // "0"')"
  if [[ -n "${loki_service_query_error}" ]]; then
    echo "[error] grafana loki service-filter query failed: ${loki_service_query_error}"
    exit 1
  fi
  if ! awk "BEGIN {exit !(${loki_service_last} > 0)}"; then
    echo "[error] expected non-empty service-filtered Loki logs for pricing dashboards, got ${loki_service_last}"
    exit 1
  fi
else
  echo "[info] grafana service is not part of state 008 compose; skipping Loki datasource assertions"
fi

echo "[check] ingress trade-service unknown ticker validation"
status_code="$(curl -sS -o /tmp/traderx-state-008-trade.out -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -d '{"security":"NOTREAL","quantity":1,"accountId":22214,"side":"Buy"}' \
  "${INGRESS_URL}/trade-service/trade")"
cat /tmp/traderx-state-008-trade.out
echo
rm -f /tmp/traderx-state-008-trade.out
if [[ "${status_code}" != "404" ]]; then
  echo "[error] expected 404 for unknown ticker through ingress, got ${status_code}"
  exit 1
fi

echo "[check] persisted trade/position include price and average cost basis"
curl -sS "http://localhost:18090/trades/22214" | jq -e 'length > 0 and (.[0].price != null)' >/dev/null || {
  echo "[error] expected persisted trades to include price"
  exit 1
}
curl -sS "http://localhost:18090/positions/22214" | jq -e 'length > 0 and (.[0].averageCostBasis != null)' >/dev/null || {
  echo "[error] expected persisted positions to include averageCostBasis"
  exit 1
}

echo "[check] baseline component smoke suite in state 008 runtime"
TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-reference-data-overlay.sh" "${ORIGIN}" "http://localhost:18085" "20"
TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-people-service-overlay.sh" "${ORIGIN}" "http://localhost:18089" "http://localhost:18088/accountuser/"
TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-account-service-overlay.sh" "${ORIGIN}" "http://localhost:18088"
TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-position-service-overlay.sh" "${ORIGIN}" "http://localhost:18090"
TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-trade-service-overlay.sh" "${ORIGIN}" "http://localhost:18092" "http://localhost:18090"
TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-web-angular-overlay.sh" "${INGRESS_URL}"
echo "[check] web-front-end state-aware UX contract"
TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-web-angular-baseline-ux-contract.sh" "${GENERATED_ROOT}/code/target-generated/web-front-end/angular"

if [[ "${SKIP_MESSAGING}" -eq 1 ]]; then
  echo "[info] skipping messaging smoke step (--skip-messaging)"
else
  echo "[check] messaging smoke step (post-functional): state 008"
  TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-messaging-008-pricing-awareness-market-data.sh" "${INGRESS_URL}" "http://localhost:18092" "22214"
fi

echo "[done] state 008 pricing-awareness runtime smoke tests passed"
