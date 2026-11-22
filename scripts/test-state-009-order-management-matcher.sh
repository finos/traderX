#!/usr/bin/env bash
set -euo pipefail

INGRESS_URL="http://localhost:8080"
ORDER_MATCHER_PORT="${ORDER_MATCHER_PORT:-18110}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-traderx-state-009}"
GRAFANA_PORT="${GRAFANA_PORT:-3001}"
GRAFANA_ADMIN_USER="${TRADERX_GRAFANA_ADMIN_USER:-traderx-admin}"
GRAFANA_ADMIN_PASSWORD="${TRADERX_GRAFANA_ADMIN_PASSWORD:-traderx-state-009}"
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
      else
        echo "[error] unknown argument: $1"
        echo "[hint] usage: $0 [INGRESS_URL] [--skip-messaging]"
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ "${TRADERX_LOCAL_RUNTIME_SCRIPT:-0}" != "1" ]]; then
  LOCAL_RUNTIME_SCRIPT="${GENERATED_ROOT}/code/target-generated/scripts/$(basename "${BASH_SOURCE[0]}")"
  if [[ -x "${LOCAL_RUNTIME_SCRIPT}" ]]; then
    args=("${INGRESS_URL}")
    if [[ "${SKIP_MESSAGING}" -eq 1 ]]; then
      args+=("--skip-messaging")
    fi
    exec "${LOCAL_RUNTIME_SCRIPT}" "${args[@]}"
  fi
fi
COMPOSE_FILE="${GENERATED_ROOT}/code/target-generated/order-management-matcher/docker-compose.yml"

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker command not found"
  exit 1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "[error] compose file not found: ${COMPOSE_FILE}"
  echo "[hint] run: bash pipeline/generate-state.sh 009-order-management-matcher"
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
if [[ "${running_services}" -lt 19 ]]; then
  echo "[error] expected 19+ running services, got ${running_services}"
  exit 1
fi

echo "[check] observability control-plane endpoints"
for endpoint in \
  "http://localhost:${GRAFANA_PORT}/api/health" \
  "http://localhost:9090/-/ready" \
  "http://localhost:3100/ready" \
  "http://localhost:3200/ready"; do
  headers="$(curl -sS -i "${endpoint}" | sed -n '1,20p')"
  echo "${headers}"
  printf '%s\n' "${headers}" | grep -q "200" || {
    echo "[error] expected 200 from ${endpoint}"
    exit 1
  }
done

echo "[check] message bus connectivity pre-check via /system/health"
check_message_bus_health_endpoint "${INGRESS_URL}/trade-service/system/health" "trade-service"
check_message_bus_health_endpoint "${INGRESS_URL}/trade-processor/system/health" "trade-processor"
check_message_bus_health_endpoint "${INGRESS_URL}/order-matcher/system/health" "order-matcher"

echo "[check] prometheus message bus connectivity metric is queryable"
message_bus_sample_count="$(
  curl -sS --get "http://localhost:9090/api/v1/query" \
    --data-urlencode 'query=traderx_messagebus_connected' \
  | jq -r '.data.result | length'
)"
if [[ "${message_bus_sample_count}" -lt 4 ]]; then
  echo "[error] expected 4+ traderx_messagebus_connected samples in Prometheus, got ${message_bus_sample_count}"
  exit 1
fi
echo "[info] traderx_messagebus_connected series=${message_bus_sample_count}"

echo "[check] order matcher health and metrics endpoints"
health_headers="$(curl -sS -i "http://localhost:${ORDER_MATCHER_PORT}/health" | sed -n '1,20p')"
echo "${health_headers}"
printf '%s\n' "${health_headers}" | grep -q "200" || {
  echo "[error] expected 200 from order matcher health endpoint"
  exit 1
}

metrics_body="$(curl -fsS "http://localhost:${ORDER_MATCHER_PORT}/metrics")"
printf '%s\n' "${metrics_body}" | rg -q '^traderx_orders_open_total' || {
  echo "[error] missing metric traderx_orders_open_total"
  exit 1
}
printf '%s\n' "${metrics_body}" | rg -q '^traderx_orders_unfilled_total' || {
  echo "[error] missing metric traderx_orders_unfilled_total"
  exit 1
}
printf '%s\n' "${metrics_body}" | rg -q '^traderx_order_events_total' || {
  echo "[error] missing metric traderx_order_events_total"
  exit 1
}
printf '%s\n' "${metrics_body}" | rg -q '^traderx_order_match_latency_seconds_bucket' || {
  echo "[error] missing metric traderx_order_match_latency_seconds histogram"
  exit 1
}
echo "[info] required order metrics detected"

echo "[check] grafana order dashboards provisioned"
dashboard_uids_raw="$(
  curl -sS -u "${GRAFANA_ADMIN_AUTH}" "http://localhost:${GRAFANA_PORT}/api/search?query=TraderX&type=dash-db" \
  | jq -r '.[].uid'
)"
if [[ -z "${dashboard_uids_raw}" ]]; then
  echo "[error] expected at least one provisioned TraderX dashboard in Grafana (type=dash-db)"
  exit 1
fi
order_metrics_dashboard_uid=""
while IFS= read -r dashboard_uid; do
  [[ -z "${dashboard_uid}" ]] && continue
  dashboard_payload="$(curl -sS -u "${GRAFANA_ADMIN_AUTH}" "http://localhost:${GRAFANA_PORT}/api/dashboards/uid/${dashboard_uid}")"
  dashboard_text="$(echo "${dashboard_payload}" | jq -r '.dashboard | tostring')"
  if printf '%s\n' "${dashboard_text}" | rg -q 'traderx_orders_open_total|traderx_order_events_total'; then
    order_metrics_dashboard_uid="${dashboard_uid}"
    break
  fi
done <<< "${dashboard_uids_raw}"
if [[ -z "${order_metrics_dashboard_uid}" ]]; then
  echo "[error] no provisioned TraderX dashboard includes order observability metric queries"
  exit 1
fi
echo "[info] grafana dashboard uid=${order_metrics_dashboard_uid} includes order observability metrics"

echo "[check] grafana includes order + spring actuator SLI dashboard coverage"
order_sli_dashboard_uid=""
while IFS= read -r dashboard_uid; do
  [[ -z "${dashboard_uid}" ]] && continue
  dashboard_payload="$(curl -sS -u "${GRAFANA_ADMIN_AUTH}" "http://localhost:${GRAFANA_PORT}/api/dashboards/uid/${dashboard_uid}")"
  dashboard_text="$(echo "${dashboard_payload}" | jq -r '.dashboard | tostring')"
  if printf '%s\n' "${dashboard_text}" | rg -q 'traderx_order_match_latency_seconds_bucket|http_server_requests_seconds_count'; then
    order_sli_dashboard_uid="${dashboard_uid}"
    break
  fi
done <<< "${dashboard_uids_raw}"
if [[ -z "${order_sli_dashboard_uid}" ]]; then
  echo "[error] no provisioned TraderX dashboard includes combined order matcher + Spring actuator SLI queries"
  exit 1
fi
echo "[info] grafana dashboard uid=${order_sli_dashboard_uid} includes order matcher + actuator SLI queries"

echo "[check] grafana includes message bus connectivity panel query"
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

echo "[check] prometheus discovered order-matcher scrape target"
target_count="$(
  curl -sS "http://localhost:9090/api/v1/targets" \
  | jq '[.data.activeTargets[] | select(((.labels.instance // "") | test("order-matcher")) or ((.discoveredLabels.__address__ // "") | test("order-matcher")))] | length'
)"
if [[ "${target_count}" -lt 1 ]]; then
  echo "[error] expected at least one active order-matcher target in Prometheus"
  exit 1
fi
echo "[info] prometheus order-matcher targets=${target_count}"

echo "[check] prometheus spring actuator scrape targets discovered"
actuator_target_count="$(
  curl -sS "http://localhost:9090/api/v1/targets" \
  | jq '[.data.activeTargets[] | select(.labels.job=="traderx-spring-boot-actuator")] | length'
)"
if [[ "${actuator_target_count}" -lt 5 ]]; then
  echo "[error] expected 5+ active Spring actuator targets, got ${actuator_target_count}"
  exit 1
fi
echo "[info] active spring actuator targets=${actuator_target_count}"

echo "[check] prometheus order-matcher actuator metrics are queryable"
order_matcher_http_samples="$(
  curl -sS --get "http://localhost:9090/api/v1/query" \
    --data-urlencode 'query=count(http_server_requests_seconds_count{job="traderx-spring-boot-actuator",instance=~".*order-matcher.*"})' \
  | jq -r '.data.result[0].value[1] // "0"'
)"
if ! awk "BEGIN {exit !(${order_matcher_http_samples} > 0)}"; then
  echo "[error] expected order-matcher Spring actuator HTTP metrics in Prometheus query results, got ${order_matcher_http_samples}"
  exit 1
fi
echo "[info] order-matcher actuator metric sample count=${order_matcher_http_samples}"

echo "[check] ingress remains healthy"
curl -fsS "${INGRESS_URL}/health" >/dev/null

echo "[check] api explorer pubsub inspector contract"
bash "${REPO_ROOT}/scripts/test-api-explorer-pubsub-inspector.sh" \
  "${INGRESS_URL}" \
  "specs/009-order-management-matcher/system/messaging-subject-map.md"

echo "[check] frontend order views use push updates (no polling regressions)"
ORDER_UI_ROOT="${GENERATED_ROOT}/code/target-generated/web-front-end/angular/main/app"
ORDER_BLOTTER_FILE="${ORDER_UI_ROOT}/trade/order-blotter/order-blotter.component.ts"
ORDER_ADMIN_FILE="${ORDER_UI_ROOT}/admin/order-admin.component.ts"
ORDER_ADMIN_SERVICE_FILE="${ORDER_UI_ROOT}/service/order-admin.service.ts"
for file in "${ORDER_BLOTTER_FILE}" "${ORDER_ADMIN_FILE}" "${ORDER_ADMIN_SERVICE_FILE}"; do
  if [[ ! -f "${file}" ]]; then
    echo "[error] expected order UI file not found: ${file}"
    exit 1
  fi
done
if rg -n 'interval\(|setInterval\(' "${ORDER_BLOTTER_FILE}" "${ORDER_ADMIN_FILE}" >/dev/null; then
  echo "[error] polling detected in order UI components; expected websocket push subscriptions"
  exit 1
fi
rg -Fq "/accounts/\${accountId}/orders" "${ORDER_BLOTTER_FILE}" || {
  echo "[error] expected order-blotter to define account-scoped realtime topic template"
  exit 1
}
rg -Fq "'/orders'" "${ORDER_BLOTTER_FILE}" || {
  echo "[error] expected order-blotter to define all-accounts realtime topic"
  exit 1
}
rg -Fq 'orderAdminService.subscribe(topic' "${ORDER_BLOTTER_FILE}" || {
  echo "[error] expected order-blotter to subscribe via orderAdminService.subscribe(topic, callback)"
  exit 1
}
rg -q '/orders' "${ORDER_ADMIN_FILE}" || {
  echo "[error] expected order-admin to subscribe to /orders realtime topic"
  exit 1
}
rg -q 'subscribe\(topic' "${ORDER_ADMIN_SERVICE_FILE}" || {
  echo "[error] expected order-admin service to expose realtime subscribe(topic, callback)"
  exit 1
}

echo "[check] order admin API through ingress"
orders_payload="$(curl -fsS "${INGRESS_URL}/order-matcher/orders?status=open")"
echo "${orders_payload}" | jq '.[0]' >/dev/null
orders_count="$(echo "${orders_payload}" | jq 'length')"
if [[ "${orders_count}" -lt 1 ]]; then
  echo "[error] expected at least one open order from ingress order-matcher API"
  exit 1
fi
echo "[info] open orders via ingress=${orders_count}"

echo "[check] user journey: create order from ticket flow"
pre_open_count="$(curl -fsS "${INGRESS_URL}/order-matcher/orders/open-count" | jq -r '.openOrders')"
create_payload='{"accountId":22214,"security":"IBM","side":"Buy","quantity":77,"limitPrice":1.000}'
create_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${create_payload}" \
    "${INGRESS_URL}/order-matcher/orders"
)"
create_http="$(echo "${create_response}" | tail -n1)"
create_body="$(echo "${create_response}" | sed '$d')"
if [[ "${create_http}" != "201" ]]; then
  echo "[error] expected 201 from create order, got ${create_http}"
  echo "${create_body}"
  exit 1
fi
created_order_id="$(echo "${create_body}" | jq -r '.orderId // empty')"
if [[ -z "${created_order_id}" ]]; then
  echo "[error] create order response missing orderId"
  echo "${create_body}"
  exit 1
fi
echo "[info] created order=${created_order_id}"

echo "[check] user journey: account-scoped open orders listing includes created order"
account_open_orders="$(curl -fsS "${INGRESS_URL}/order-matcher/orders?status=open&accountId=22214")"
listed_count="$(echo "${account_open_orders}" | jq --arg order_id "${created_order_id}" '[.[] | select(.orderId == $order_id)] | length')"
if [[ "${listed_count}" -lt 1 ]]; then
  echo "[error] expected created order ${created_order_id} in account open-orders listing"
  exit 1
fi

echo "[check] user journey: cancel open order"
cancel_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{}' \
    "${INGRESS_URL}/order-matcher/orders/${created_order_id}/cancel"
)"
cancel_http="$(echo "${cancel_response}" | tail -n1)"
cancel_body="$(echo "${cancel_response}" | sed '$d')"
if [[ "${cancel_http}" != "200" ]]; then
  echo "[error] expected 200 from cancel order, got ${cancel_http}"
  echo "${cancel_body}"
  exit 1
fi
cancel_status="$(echo "${cancel_body}" | jq -r '.status // empty')"
if [[ "${cancel_status}" != "CANCELED" ]]; then
  echo "[error] expected canceled order status, got ${cancel_status}"
  echo "${cancel_body}"
  exit 1
fi

echo "[check] admin journey: force-fill an open order"
pre_trade_count="$(curl -fsS "${INGRESS_URL}/position-service/trades/44044" | jq 'length')"
pre_jpm_position_qty="$(curl -fsS "${INGRESS_URL}/position-service/positions/44044" | jq -r '[.[] | select(.security == "JPM")][0].quantity // 0')"
admin_create_payload='{"accountId":44044,"security":"JPM","side":"Sell","quantity":55,"limitPrice":191.875}'
admin_create_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${admin_create_payload}" \
    "${INGRESS_URL}/order-matcher/orders"
)"
admin_create_http="$(echo "${admin_create_response}" | tail -n1)"
admin_create_body="$(echo "${admin_create_response}" | sed '$d')"
if [[ "${admin_create_http}" != "201" ]]; then
  echo "[error] expected 201 from admin setup create order, got ${admin_create_http}"
  echo "${admin_create_body}"
  exit 1
fi
admin_order_id="$(echo "${admin_create_body}" | jq -r '.orderId // empty')"
if [[ -z "${admin_order_id}" ]]; then
  echo "[error] admin setup create order missing orderId"
  echo "${admin_create_body}"
  exit 1
fi
force_fill_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{}' \
    "${INGRESS_URL}/order-matcher/orders/${admin_order_id}/force-fill"
)"
force_fill_http="$(echo "${force_fill_response}" | tail -n1)"
force_fill_body="$(echo "${force_fill_response}" | sed '$d')"
if [[ "${force_fill_http}" != "200" ]]; then
  echo "[error] expected 200 from force-fill order, got ${force_fill_http}"
  echo "${force_fill_body}"
  exit 1
fi
force_fill_status="$(echo "${force_fill_body}" | jq -r '.status // empty')"
if [[ "${force_fill_status}" != "FILLED" ]]; then
  echo "[error] expected force-filled order status FILLED, got ${force_fill_status}"
  echo "${force_fill_body}"
  exit 1
fi
echo "[check] force-filled order created trade and changed position"
trade_observed=0
for _ in {1..30}; do
  trades_after="$(curl -fsS "${INGRESS_URL}/position-service/trades/44044")"
  trade_count_after="$(echo "${trades_after}" | jq 'length')"
  matched_trade_count="$(echo "${trades_after}" | jq '[.[] | select(.security == "JPM" and .side == "Sell" and .quantity == 55)] | length')"
  if [[ "${trade_count_after}" -gt "${pre_trade_count}" && "${matched_trade_count}" -ge 1 ]]; then
    trade_observed=1
    break
  fi
  sleep 2
done
if [[ "${trade_observed}" -ne 1 ]]; then
  echo "[error] expected force-fill to produce persisted JPM sell trade for account 44044"
  exit 1
fi
expected_jpm_position_qty="$((pre_jpm_position_qty - 55))"
position_observed=0
for _ in {1..30}; do
  position_rows="$(curl -fsS "${INGRESS_URL}/position-service/positions/44044")"
  current_jpm_qty="$(echo "${position_rows}" | jq -r '[.[] | select(.security == "JPM")][0].quantity // 0')"
  if [[ "${current_jpm_qty}" == "${expected_jpm_position_qty}" ]]; then
    position_observed=1
    break
  fi
  sleep 2
done
if [[ "${position_observed}" -ne 1 ]]; then
  echo "[error] expected JPM position quantity=${expected_jpm_position_qty} after force-fill"
  exit 1
fi

echo "[check] matcher journey: in-the-money order auto-fills on tick policy"
autofill_create_payload='{"accountId":22214,"security":"IBM","side":"Buy","quantity":5000,"limitPrice":99999.000}'
autofill_create_response="$(
  curl -sS -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -X POST \
    -d "${autofill_create_payload}" \
    "${INGRESS_URL}/order-matcher/orders"
)"
autofill_create_http="$(echo "${autofill_create_response}" | tail -n1)"
autofill_create_body="$(echo "${autofill_create_response}" | sed '$d')"
if [[ "${autofill_create_http}" != "201" ]]; then
  echo "[error] expected 201 from auto-fill setup create order, got ${autofill_create_http}"
  echo "${autofill_create_body}"
  exit 1
fi
autofill_order_id="$(echo "${autofill_create_body}" | jq -r '.orderId // empty')"
if [[ -z "${autofill_order_id}" ]]; then
  echo "[error] auto-fill setup create order missing orderId"
  echo "${autofill_create_body}"
  exit 1
fi
autofill_first_remaining=""
for _ in {1..20}; do
  autofill_order="$(curl -fsS "${INGRESS_URL}/order-matcher/orders/${autofill_order_id}")"
  autofill_status="$(echo "${autofill_order}" | jq -r '.status // empty')"
  autofill_remaining="$(echo "${autofill_order}" | jq -r '.remainingQuantity // -1')"
  if [[ "${autofill_status}" != "NEW" ]]; then
    autofill_first_remaining="${autofill_remaining}"
    break
  fi
  sleep 1
done
if [[ -z "${autofill_first_remaining}" ]]; then
  echo "[error] expected auto-fill order to progress from NEW on matcher ticks"
  exit 1
fi
case "${autofill_first_remaining}" in
  2500|1250|625|0) ;;
  *)
    echo "[error] auto-fill remaining quantity did not follow expected reduction policy, got ${autofill_first_remaining}"
    exit 1
    ;;
esac
autofill_terminal=0
for _ in {1..40}; do
  autofill_order="$(curl -fsS "${INGRESS_URL}/order-matcher/orders/${autofill_order_id}")"
  autofill_status="$(echo "${autofill_order}" | jq -r '.status // empty')"
  if [[ "${autofill_status}" == "FILLED" ]]; then
    autofill_terminal=1
    break
  fi
  sleep 1
done
if [[ "${autofill_terminal}" -ne 1 ]]; then
  echo "[error] expected auto-fill order ${autofill_order_id} to reach FILLED"
  exit 1
fi

echo "[check] lifecycle metrics include create/cancel/force_fill counters"
metrics_after_lifecycle="$(curl -fsS "http://localhost:${ORDER_MATCHER_PORT}/metrics")"
printf '%s\n' "${metrics_after_lifecycle}" | rg -q 'traderx_order_events_total\{event="create"\}' || {
  echo "[error] missing create event counter after lifecycle actions"
  exit 1
}
printf '%s\n' "${metrics_after_lifecycle}" | rg -q 'traderx_order_events_total\{event="cancel"\}' || {
  echo "[error] missing cancel event counter after lifecycle actions"
  exit 1
}
printf '%s\n' "${metrics_after_lifecycle}" | rg -q 'traderx_order_events_total\{event="force_fill"\}' || {
  echo "[error] missing force_fill event counter after lifecycle actions"
  exit 1
}
post_open_count="$(curl -fsS "${INGRESS_URL}/order-matcher/orders/open-count" | jq -r '.openOrders')"
if (( post_open_count > pre_open_count + 1 )); then
  echo "[error] open-order count increased unexpectedly (before=${pre_open_count}, after=${post_open_count})"
  exit 1
fi
echo "[info] order lifecycle checks passed (open orders before=${pre_open_count}, after=${post_open_count})"

echo "[check] admin route served by web UI"
admin_headers="$(curl -sS -i "${INGRESS_URL}/admin" | sed -n '1,20p')"
echo "${admin_headers}"
printf '%s\n' "${admin_headers}" | grep -q "200" || {
  echo "[error] expected admin route to return 200"
  exit 1
}

echo "[check] grafana loki datasource has non-empty log streams in order-management runtime"
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

echo "[check] dashboard service-filtered logs are present (nats/pricing/control-plane/order)"
loki_service_query_result="$(
  curl -sS -u "${GRAFANA_ADMIN_AUTH}" -H 'Content-Type: application/json' -X POST "http://localhost:${GRAFANA_PORT}/api/ds/query" \
    -d "{\"from\":\"${from_ms}\",\"to\":\"${now_ms}\",\"queries\":[{\"refId\":\"A\",\"datasource\":{\"uid\":\"loki\",\"type\":\"loki\"},\"expr\":\"sum(count_over_time({compose_project=\\\"${COMPOSE_PROJECT_NAME}\\\",service=~\\\"nats-broker|price-publisher|trade-service|trade-processor|position-service|order-matcher|web-front-end-angular|grafana|loki|tempo|otel-collector|prometheus|promtail\\\"}[10m]))\",\"queryType\":\"range\",\"intervalMs\":1000,\"maxDataPoints\":500}]}"
)"
loki_service_query_error="$(echo "${loki_service_query_result}" | jq -r '.results.A.error // empty')"
loki_service_last="$(echo "${loki_service_query_result}" | jq -r '.results.A.frames[0].data.values[1][-1] // "0"')"
if [[ -n "${loki_service_query_error}" ]]; then
  echo "[error] grafana loki service-filter query failed: ${loki_service_query_error}"
  exit 1
fi
if ! awk "BEGIN {exit !(${loki_service_last} > 0)}"; then
  echo "[error] expected non-empty service-filtered Loki logs for dashboards, got ${loki_service_last}"
  exit 1
fi

echo "[check] web-front-end state-aware UX contract"
TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-web-angular-baseline-ux-contract.sh" "${GENERATED_ROOT}/code/target-generated/web-front-end/angular"

if [[ "${SKIP_MESSAGING}" -eq 1 ]]; then
  echo "[info] skipping messaging smoke step (--skip-messaging)"
else
  echo "[check] messaging smoke step (post-functional): state 009"
  TRADERX_LOCAL_RUNTIME_SCRIPT=1 "${REPO_ROOT}/scripts/test-messaging-009-order-management-matcher.sh" "${INGRESS_URL}" "http://localhost:18092" "22214"
fi

echo "[done] state 009 order-management observability smoke tests passed"
